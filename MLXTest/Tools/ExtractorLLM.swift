//
//  ExtractorLLM.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 26/07/25.
//

import Foundation
import FoundationModels

@Observable
class ExtractorLLM {
    
    private var session: LanguageModelSession
    
    init() {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM yyyy"
        
        let systemPrompt = """
You are a helpful assistant that given a QUERY and a CONTEXT, extract relevant information from the CONTEXT that may help answer the QUERY. \
Prefer citing exactly the CONTEXT if you can. Pay attention to dates. \
*IMPORTANT* Today's date is: \(formatter.string(from: Date()))
"""
        self.session = LanguageModelSession(instructions: systemPrompt)
        self.session.prewarm()
    }
    
    func extract(_ query: String, from context: String) async -> String {
        let prompt = """
            QUERY: \(query) \
            CONTEXT: \(context) \
            Extract relevant information.
            """
        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize(let context) {
            print("[DEBUG] Error: \(context.debugDescription)")
            return ""
        } catch LanguageModelSession.GenerationError.guardrailViolation(let context) {
            print("[DEBUG] Error: \(context.debugDescription)")
            return ""
        } catch {
            print("[DEBUG] Error: \(error.localizedDescription)")
            return ""
        }
    }
        
}
