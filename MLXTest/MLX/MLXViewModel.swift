//
//  MLXViewModel.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 7/11/25.
//

import Foundation
import Hub
import MLXLLM
import MLXVLM
import MLXLMCommon
internal import Tokenizers
import Combine
import Readability

struct FunctionCall: Decodable {
    let name: String
    let parameters: [String: String]
}

@MainActor
@Observable
class MLXViewModel {
    
    private var modelConfiguration: ModelConfiguration?
    private var serperAPI = SerperAPI()
    
    var modelContainer: ModelContainer?
    
    private var systemPrompt = "You are a helpful assistant."
    
    var output = ""
    var tokensPerSecond: Double = 0
    var isRunning = false
    var downloadProgress: Progress?
    var downloadFraction: Double = 0.0
    var errorMessage: String?
    var chat: [Chat.Message] = []
    
    private let hub = HubApi(downloadBase: URL.downloadsDirectory.appending(path: "huggingface"))
    
    private var modelFactory: ModelFactory {
        let isLLM = LLMModelFactory.shared.modelRegistry.models.contains { $0.name == modelConfiguration!.name }
        return if isLLM {
            LLMModelFactory.shared
        } else {
            VLMModelFactory.shared
        }
    }
    
    init() {
        self.modelConfiguration = CustomModels.llama3_2_3B_4bit.modelConfiguration()
    }
    
    func setModelConfiguration(_ modelConfiguration: ModelConfiguration) {
        self.modelConfiguration = modelConfiguration
    }
    
    func getModelConfiguration() -> ModelConfiguration? {
        return self.modelConfiguration
    }
    
    public func loadModel() async {
        do {
            modelContainer = try await modelFactory.loadContainer(
                configuration: modelConfiguration!
            ) { progress in
                Task { @MainActor in
                    print(self.downloadProgress?.fractionCompleted ?? 0.0)
                    self.downloadProgress = progress
                    self.downloadFraction = progress.fractionCompleted
                }
            }
        } catch {
            print(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }
    
    let webSearchToolSpec: [String: any Sendable] = [
        "type": "function",
        "function": [
            "name": "search_web",
            "description": "Get up-to-date information through web search",
            "parameters": [
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "The query to send to the search engine",
                    ],
                ],
                "required": ["query"]
            ]
        ]
    ]
    
    func generate(messages: [Chat.Message], includeWebSearch: Bool = false) async {
        let tools = includeWebSearch ? [webSearchToolSpec] : []
        isRunning = true
        
        if modelContainer == nil {
            await loadModel()
        }
        
        guard let modelContainer else {
            isRunning = false
            return
        }
        
        do {
            let result = try await modelContainer.perform { @MainActor context in
                var systemMessages = messages
                systemMessages.insert(.init(role: .system, content: systemPrompt), at: 0)
                
                var userInput: UserInput
                if includeWebSearch {
                    // Capture the genuine user query before any placeholder or streaming updates
                    userInput = UserInput(chat: systemMessages, tools: tools)
                } else {
                    userInput = UserInput(chat: systemMessages)
                }
                
                var input = try await context.processor.prepare(input: userInput)
                
                if includeWebSearch {
                    let originalQuery = messages.last(where: { $0.role == .user })?.content ?? ""
                    let llmContext = try await handleToolCall(input: input, context: context, query: originalQuery)
                    let userContext = """
                        This is the original user query: \(originalQuery) \
                        ----------------- \
                        This is the context from a web search: \
                        \(llmContext.joined()) \
                        -----------------
                        Find the answer to the user question.\
                        For context today is: \(Date()) \\
                        """
                    
                    print("[DEBUG] Context: \(userContext)")
                    
                    let contextMessage = Chat.Message(
                        role: .user,
                        content: userContext
                    )
                    systemMessages.append(contextMessage)
                    userInput = UserInput(chat: systemMessages)
                    input = try await context.processor.prepare(input: userInput)
                }
                
                return try MLXLMCommon.generate(input: input, parameters: .init(), context: context) { tokens in
                    let text = context.tokenizer.decode(tokens: tokens)
                    
                    Task { @MainActor in
                        chat[chat.count-1].content = text
                        output = text
                    }
                    
                    return .more
                }
            }
            
            tokensPerSecond = result.tokensPerSecond
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isRunning = false
    }
    
    private nonisolated func createPrompt(_ prompt: String, images: [UserInput.Image]) -> UserInput.Prompt {
        if images.isEmpty {
            return .text(prompt)
        } else {
            let message: Message = [
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt]
                ] + images.map { _ in ["type": "image"] }
            ]
            
            return .messages([message])
        }
    }
    
    private func extractFunctionCallFrom(_ response: String) -> FunctionCall? {
        let pattern = #"<\|python_tag\|>(.*?)<\|eom_id\|>"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        if
            let match = regex.firstMatch(in: response, range: .init(location: 0, length: response.utf16.count)),
            let range = Range(match.range(at: 1), in: response)
        {
            let jsonString = String(response[range])
            print(jsonString)
            let data = Data(jsonString.utf8)
            do {
                let call = try JSONDecoder().decode(FunctionCall.self, from: data)
                return call
            } catch {
                print("[DEBUG] Error: \(error.localizedDescription)")
            }
        }
        return nil
    }
    
    private func handleToolCall(input: LMInput, context: ModelContext, query: String) async throws -> [String] {
        var callStream: String = ""
        let stream = try MLXLMCommon.generate(input: input, parameters: .init(), context: context)
        for await generation in stream {
            switch generation {
            case .chunk(let token):
                callStream += token
            case .info(let info):
                print("Tool call completed: \(info)")
            }
        }
        
        var context: [String] = []
        
        if let call = extractFunctionCallFrom(callStream) {
            let webSearchQuery = call.parameters["query"]!
            let response = try await serperAPI.search(query: webSearchQuery)
            let links = response.organicResults.map(\.link)
            let crawler = FirecrawlAPI()
            
            for link in links[...5] {
                print("[DEBUG] Extracting content from: \(link)")
                do {
                    let raw = try await crawler.scrapeMarkdown(from: link).replacingOccurrences(of: "\n", with: "")
                    let summary = try await shortSummarize(text: raw, userQuery: query)
                    print("[DEBUG] summary: \(summary)")
                    context.append(summary)
                } catch {
                    print("[DEBUG] Error extracting content: \(error.localizedDescription)")
                    continue
                }
            }
        }
        
        return context
    }
    
    /// Summarizes the given text into a short, 3-sentence summary.
    private func shortSummarize(text: String, userQuery: String) async throws -> String {
        // Ensure the model is loaded
        if modelContainer == nil {
            await loadModel()
        }
        guard let modelContainer = modelContainer else {
            throw NSError(domain: "MLXViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }

        // Build the summarization prompt
        let prompt = """
        This is the ORIGINAL_QUERY: \(userQuery). \
        Please provide a concise summary of the following text citing part of the text that may be relevant to the ORIGINAL_QUERY: \
        \(text.replacingOccurrences(of: "\n", with: "")) \\
        For context today is: \(Date())
        """

        // Prepare chat messages
        let messages: [Chat.Message] = [
            .init(role: .system, content: systemPrompt),
            .init(role: .user, content: prompt)
        ]

        // Prepare the user input without any tools or function calling
        let userInput = UserInput(chat: messages)

        // Get the input for the model
        let input = try await modelContainer.perform { @MainActor context in
            let prepared = try await context.processor.prepare(input: userInput)
            return prepared
        }

        // Generate the summary
        var summary = ""
        let _ = try await modelContainer.perform { context in
            return try MLXLMCommon.generate(input: input, parameters: .init(), context: context) { tokenBatch in
                let chunk = context.tokenizer.decode(tokens: tokenBatch)
                Task { @MainActor in
                    summary = chunk
                }
                return .more
            }
        }

        return summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
