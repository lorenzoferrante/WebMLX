//
//  FirecrawlAPI.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 26/07/25.
//

import Foundation
// MARK: - Firecrawl API Models

private struct FirecrawlResponse: Decodable {
    let success: Bool
    let data: FirecrawlData?
}

private struct FirecrawlData: Decodable {
    let markdown: String
    let metadata: Metadata
}

private struct Metadata: Decodable {
    let title: String
    let description: String
    let language: String?
    let sourceURL: URL
}

private struct ScrapeRequest: Encodable {
    let url: String
    let formats: [String]
    let onlyMainContent: Bool
    let parsePDF: Bool
    let maxAge: Int
}

// MARK: - Firecrawl API Client

/// A client for scraping web pages via the Firecrawl API and extracting Markdown content.
public class FirecrawlAPI {
    /// API key is loaded from environment to avoid hardcoding secrets.
    private let apiKey: String = "fc-86cab48709644bfe880cacbff636e7fc"
    private let session: URLSession

    /// Initialize with your Firecrawl API key.
    /// - Parameters:
    ///   - apiKey: Your Firecrawl API Bearer token.
    ///   - session: URLSession instance, defaults to `.shared`.
    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Scrape the given page URL and return its Markdown content.
    /// - Parameter urlString: The URL of the webpage to scrape.
    /// - Returns: The scraped Markdown string.
    public func scrapeMarkdown(from urlString: String) async throws -> String {
        // Build request
        guard let endpoint = URL(string: "https://api.firecrawl.dev/v1/scrape") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Encode body
        let body = ScrapeRequest(
            url: urlString,
            formats: ["markdown"],
            onlyMainContent: true,
            parsePDF: true,
            maxAge: 14_400_000
        )
        request.httpBody = try JSONEncoder().encode(body)

        // Perform network call
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        // Decode response
        let result = try JSONDecoder().decode(FirecrawlResponse.self, from: data)
        guard result.success, let markdown = result.data?.markdown else {
            throw NSError(domain: "FirecrawlAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve markdown"])
        }

        return markdown
    }
}
