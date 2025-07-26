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
import SwiftUI

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
    
    private var systemPrompt = """
    You are a helpful assistant that has web access.
    If no web search is specified, reply normally.
    If web search is specified, be extra careful with the current date to provide up-to-date information.
    Try to extract the meaning of what the user is asking, considering that this is a turn-based conversation.
    """
    
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
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM yyyy"
        return formatter.string(from: Date())
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
            StatusManager.shared.clearStatus()
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
                    StatusManager.shared.setStatus(to: "Performing web search...")
                    
                    let originalQueries = messages.filter({$0.role == .user}).map({$0.content}).joined(separator: "\n")
                    let originalQuery = messages.last(where: { $0.role == .user })?.content ?? ""
                    let llmContext = try await handleToolCall(input: input, modelContext: context, query: originalQuery)
                    let userContext = """
                        Please extract the answer to the ORIGINAL_QUERY with the following context. \
                        Try to stay as concise as possible. Be extremely careful with dates, always report up-to-date information. \
                        TODAY DATE: \(formattedDate) \
                        ORIGINAL QUERY: \(originalQueries) \
                        CONTEXT: \
                        \(llmContext.joined()) \
                        Answer:
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
                
                StatusManager.shared.setStatus(to: "Finalizing answer...")
                
                return try MLXLMCommon.generate(input: input, parameters: .init(), context: context) { tokens in
                    let text = context.tokenizer.decode(tokens: tokens)
                    
                    Task { @MainActor in
                        chat[chat.count-1].content = text
                        output = text
                    }
                    
                    StatusManager.shared.clearStatus()
                    return .more
                }
            }
            
            tokensPerSecond = result.tokensPerSecond
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isRunning = false
        StatusManager.shared.clearStatus()
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
    
    private func handleToolCall(input: LMInput, modelContext: ModelContext, query: String) async throws -> [String] {
        var callStream: String = ""
        let stream = try MLXLMCommon.generate(input: input, parameters: .init(), context: modelContext)
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
            
            for link in links[...4] {
                StatusManager.shared.setStatus(to: "Reading \(link)...")
                
                print("[DEBUG] Extracting content from: \(link)")
                do {
                    let raw = try await crawler.scrapeMarkdown(from: link).replacingOccurrences(of: "\n", with: "")
                    let summary = try await shortSummarize(text: raw, userQuery: query, context: modelContext)
                    
                    StatusManager.shared.setStatus(to: "Summarizing \(link)...")
                    
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
    
    /// Splits text into segments where each segment's token count does not exceed maxTokens.
    private func chunkByTokens(text: String, maxTokens: Int, context: ModelContext) -> [String] {
        let allTokens = context.tokenizer.encode(text: text)
        var segments: [String] = []
        var index = 0
        while index < allTokens.count {
            let end = min(index + maxTokens, allTokens.count)
            let slice = Array(allTokens[index..<end])
            let segmentText = context.tokenizer.decode(tokens: slice)
            segments.append(segmentText)
            index = end
        }
        return segments
    }

    /// Summarizes the given text into a short, 3-sentence summary.
    private func shortSummarize(text: String, userQuery: String, context: ModelContext) async throws -> String {
        // Ensure the model is loaded
        if modelContainer == nil {
            await loadModel()
        }
        guard modelContainer != nil else {
            throw NSError(domain: "MLXViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }

        // Chunk large texts based on token count to fit within an 8192-token context window
        let maxModelTokens = 8192
        let reservedTokens = 212  // reserve tokens for prompt overhead and summary
        let maxChunkTokens = maxModelTokens - reservedTokens

        // Remove newlines for consistent tokenization
        let sanitizedText = text.replacingOccurrences(of: "\n", with: "")
        // Count tokens
        let tokenCount = context.tokenizer.encode(text: sanitizedText).count
        // If text exceeds our token budget, split and summarize recursively
        if tokenCount > maxChunkTokens {
            // Split into segments of maxChunkTokens
            let segments = chunkByTokens(text: sanitizedText, maxTokens: maxChunkTokens, context: context)
            var partialSummaries: [String] = []
            for segment in segments {
                StatusManager.shared.setStatus(to: "Summaring chunk ...")
                let segSummary = try await shortSummarize(text: segment, userQuery: userQuery, context: context)
                partialSummaries.append(segSummary)
            }
            let merged = partialSummaries.joined(separator: "\n")
            return try await shortSummarize(text: merged, userQuery: userQuery, context: context)
        }

        // Build the summarization prompt
        let prompt = """
        TODAY DATE: \(formattedDate) \
        ORIGINAL_QUERY: \(userQuery). \
        Please extract relevant information from the following context trying to answer the ORIGINAL_QUERY. \
        Try to stay as concise as possible. Be extremely careful with dates, always report up-to-date information. \
        If no valid information is found, return an empty string. \
        CONTEXT: \
        \(text.replacingOccurrences(of: "\n", with: ""))
        """

        // Prepare chat messages
        let messages: [Chat.Message] = [
            .init(role: .system, content: systemPrompt),
            .init(role: .user, content: prompt)
        ]

        // Prepare the user input without any tools or function calling
        let userInput = UserInput(chat: messages)

        // Get the input for the model
        let prepared = try await context.processor.prepare(input: userInput)

        // Generate the summary
        var summary = ""
        _ = try MLXLMCommon.generate(input: prepared, parameters: .init(), context: context) { tokenBatch in
            let chunk = context.tokenizer.decode(tokens: tokenBatch)
            summary = chunk
            return .more
        }

        return summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

