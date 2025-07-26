//
//  Tools.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 26/07/25.
//

import Foundation

// MARK: - Serper API Networking
final class SerperAPI {
    private let apiKey: String = "e246e47eb961fb6fe6b9c78b0b336f335a529aa2bc537616acbccd4cadf64f2e"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Searches Serper and returns the parsed response.
    /// - Parameters:
    ///   - query: Your search query (e.g. "next f1 race")
    ///   - location: The location to search from (default: "Italy")
    ///   - googleDomain: The Google domain to use (default: "google.it")
    ///   - hl: Language code (default: "it")
    ///   - gl: Country code (default: "it")
    @available(macOS 12, iOS 15, *)
    func search(
        query: String,
        location: String = "Italy",
        googleDomain: String = "google.it",
        hl: String = "it",
        gl: String = "it"
    ) async throws -> SerperResponse {
        var components = URLComponents(string: "https://serpapi.com/search")!
        components.queryItems = [
            URLQueryItem(name: "engine", value: "google_light"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "location", value: location),
            URLQueryItem(name: "google_domain", value: googleDomain),
            URLQueryItem(name: "hl", value: hl),
            URLQueryItem(name: "gl", value: gl),
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        // Optional: basic HTTP status check
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        
        do {
            return try JSONDecoder().decode(SerperResponse.self, from: data)
        } catch {
            throw error
        }
    }
}

// MARK: - Data Models

struct SerperResponse: Decodable {
    let organicResults: [OrganicResult]
    private enum CodingKeys: String, CodingKey {
        case organicResults = "organic_results"
    }
}

struct OrganicResult: Decodable {
    let title: String
    let link: String
}
