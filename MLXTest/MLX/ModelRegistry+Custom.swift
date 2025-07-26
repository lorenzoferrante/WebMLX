//
//  ModelRegistry+Custom.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 7/11/25.
//

import Foundation
import MLXLLM
import MLXLMCommon
import MLXVLM

enum CustomModels: String, Hashable, CaseIterable {
    case llama3_2_3B_4bit
    
    func modelConfiguration() -> ModelConfiguration {
        switch self {
        case .llama3_2_3B_4bit:
            return LLMRegistry.llama3_2_3B_4bit
        }
    }
}

extension LLMRegistry {
    func registerCustomModels() {
    }
}
