//
//  LLM.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 26/07/25.
//

import Foundation
import FoundationModels
import MLXLMCommon

@MainActor
@Observable
class LLM {
    private let queryConverterLLM: QueryConverterLLM
    private let session: LanguageModelSession
    private let systemPrompt: String
    var chat: [Chat.Message] = []
    
    var isResponding: Bool {
        self.session.isResponding
    }
    
    init() {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM yyyy"
        
        queryConverterLLM = QueryConverterLLM()
        
        systemPrompt = """
You are a helpful assistant that has web access. \
Turn the user query into a web engine query, search the web and the extract the information. \
You have access to a web-search tool that lets you search the web for up-to-date information. \
*IMPORTANT* Today's date is: \(formatter.string(from: Date()))
"""
        let webSearchTool = WebSearchTool()
        session = LanguageModelSession(tools: [webSearchTool], instructions: systemPrompt)
    }
    
    func generateResponse(from currentChat: [Chat.Message]) async throws {
        let query = await queryConverterLLM.extract(currentChat)
        print("[DEBUG] Query: \(query)")
        
        let stream = session.streamResponse(to: query)
        StatusManager.shared.setStatus(to: "Finalizing answer...")
        for try await token in stream {
            chat[chat.count-1].content = token
        }
        StatusManager.shared.clearStatus()
    }
        
}
