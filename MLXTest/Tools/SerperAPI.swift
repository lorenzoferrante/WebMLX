//
//  Tools.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 26/07/25.
//

import Foundation

// MARK: - Serper API Networking
final class SerperAPI {
    /// API key is loaded from environment to avoid hardcoding secrets.
    private let apiKey: String = "644a912a64bbfd323bda9190ac97c60974236e1c"
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }

    @available(macOS 12, iOS 15, *)
    func search(query: String) async throws -> SerperResponse {
        // Build JSON body
        let requestBody = [
            "q": query
        ]
        let bodyData = try JSONEncoder().encode(requestBody)
        
        // Configure request
        guard let url = URL(string: "https://google.serper.dev/search") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        
        // Perform request
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        
        // Decode and return
        let result = try JSONDecoder().decode(SerperResponse.self, from: data)
        return result
    }
}

// MARK: - Data Models

struct SerperResponse: Decodable {
    let organic: [OrganicResult]
}

struct OrganicResult: Decodable {
    let title: String
    let link: String
}
