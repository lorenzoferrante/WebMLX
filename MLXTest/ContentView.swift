//
//  ContentView.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 7/11/25.
//

import SwiftUI
import MLXLLM
import MLXVLM
import MLXLMCommon

struct ContentView: View {
    
    @State var vm: MLXViewModel = MLXViewModel()
    @State var statusManager = StatusManager.shared
    
    private let bottomID = "bottomID"
    
    private var lastMessageContent: String {
        vm.chat.last?.content ?? ""
    }
    
    @State var showModelSelection: Bool = false
    @State private var prompt: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                ChatView(vm: $vm)
                    .ignoresSafeArea(.keyboard)
                BottomBar(vm: $vm, prompt: $prompt)
                StatusView()
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        reset()
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
                
                ToolbarItem {
                    Button {
                        showModelSelection.toggle()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .onAppear {
                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                print(documents.absoluteString)
                if vm.getModelConfiguration() == nil {
                    showModelSelection.toggle()
                } else {
                    Task {
                        await vm.loadModel()
                    }
                }
            }
            .sheet(isPresented: $showModelSelection) {
                ModelSelectorView(vm: $vm)
            }
        }
    }
    
    private func reset() {
        withAnimation {
            vm.chat.removeAll()
            vm.output = ""
            vm.tokensPerSecond = 0
            prompt = ""
        }
    }
}

#Preview {
    ContentView()
}

