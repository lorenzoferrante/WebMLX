//
//  StatusManager.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 26/07/25.
//

import Foundation
import SwiftUI

@MainActor
@Observable
class StatusManager {
    
    static let shared = StatusManager()
    
    var status: String = ""
    
    private init() {}
    
    public func setStatus(to status: String) {
        withAnimation(.easeInOut) {
            self.status = status
        }
    }
    
    public func clearStatus() {
        setStatus(to: "")
    }
    
}
