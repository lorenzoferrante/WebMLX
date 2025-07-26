//
//  StatusManager.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 26/07/25.
//

import Foundation

@MainActor
@Observable
class StatusManager {
    
    static let shared = StatusManager()
    
    var status: String = ""
    
    private init() {}
    
}
