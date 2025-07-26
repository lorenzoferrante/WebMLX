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

@MainActor
@Observable
class MLXViewModel {
    
    private var modelConfiguration: ModelConfiguration?
    
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
                //                hub: hub,
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
                let userInput = UserInput(chat: systemMessages, tools: tools)
                let input = try await context.processor.prepare(input: userInput)
                
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
}
