//
//  QueryConverter.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 26/07/25.
//

import Foundation
import FoundationModels
import MLXLMCommon

@Observable
class QueryConverterLLM {
    
    @Generable
    struct ResultQuery {
        @Guide(description: "Short query feedable to a search engine")
        var query: String
    }
    
    private var session: LanguageModelSession
    
    init() {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM yyyy"
        
        var systemPrompt = """
You are a helpful assistant that turns the user conversation into short single-line query feedable to a search engine.  
"""
        self.session = LanguageModelSession(instructions: systemPrompt)
        self.session.prewarm()
    }
    
    func extract(_ query: [Chat.Message]) async -> String {
        let latestUserQuery = query.filter({ $0.role == .user }).map(\.content).joined(separator: "\n")
        let prompt = """
            USER_QUERIES: \(latestUserQuery)
            Turn the USER_QUERIES into short single-line query feedable to a search engine.
            """
        do {
            let response = try await session.respond(to: prompt, generating: ResultQuery.self)
            return response.content.query
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize(let context) {
            print("[DEBUG] Error: \(context.debugDescription)")
        } catch LanguageModelSession.GenerationError.guardrailViolation(let context) {
            print("[DEBUG] Error: \(context.debugDescription)")
        } catch {
            print("[DEBUG] Error: \(error.localizedDescription)")
        }
        return ""
    }
        
}
