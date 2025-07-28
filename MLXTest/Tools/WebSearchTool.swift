//
//  WebSearchTool.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 26/07/25.
//

import Foundation
import FoundationModels

struct WebSearchTool: Tool {
    let name = "webSearch"
    let description = "Get up to date information from the web"
    
    private var serperAPI: SerperAPI
    private var firecrawlAPI: FirecrawlAPI
    private let extractorLLM: ExtractorLLM
    
    init() {
        self.serperAPI = SerperAPI()
        self.firecrawlAPI = FirecrawlAPI()
        self.extractorLLM = ExtractorLLM()
    }
    
    @Generable
    struct Arguments {
        @Guide(description: "Query to feed a search engine")
        let query: String
    }
    
    func call(arguments: Arguments) async throws -> [String] {
        StatusManager.shared.setStatus(to: "Performing web search for \(arguments.query)")
        var summaries: [String] = []
        let response: SerperResponse
        
        do {
            response = try await serperAPI.search(query: arguments.query)
        } catch {
            print("🔍 Search JSON decode error:", error)
            return []
        }
        
        for link in response.organic.map(\.link) {
            do {
                StatusManager.shared.setStatus(to: "Reading \(link)")
                let markdown = try await firecrawlAPI.scrapeMarkdown(from: link)
                print("[DEBUG] Markdown:", markdown)
                
                StatusManager.shared.setStatus(to: "Summarizing \(link)")
                let extracted = await extractorLLM.extract(arguments.query, from: markdown)
                summaries.append(extracted)
            } catch {
                print("🕸️ Scrape JSON decode error for \(link):", error)
            }
        }
        
        return summaries
    }
    
    
}
