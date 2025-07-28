//
//  BottomBar.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 7/25/25.
//

import SwiftUI
import MLXLMCommon

struct BottomBar: View {
    @Binding var vm: LLM
    @Binding var prompt: String
    
    @FocusState private var isFocused: Bool
    
    @State var isWebSearch: Bool = true
    
    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            
            GlassEffectContainer {
                VStack(alignment: .leading) {
                    //                    if vm.downloadProgress != nil {
                    //                        if vm.downloadProgress?.isFinished == false {
                    //                            Text("Downloading model: \(vm.downloadFraction * 100, specifier: "%.1f")%")
                    //                                .font(.caption)
                    //                                .padding([.top, .leading, .trailing])
                    //                                .foregroundStyle(.secondary)
                    //                        }
                    //                    } else if vm.errorMessage != nil {
                    //                        Text("Error: \(vm.errorMessage!)")
                    //                            .font(.caption)
                    //                            .padding([.top, .leading, .trailing])
                    //                            .foregroundStyle(.red)
                    //                    }
                    
                    VStack {
                        TextField("Ask anything...", text: $prompt)
                            .padding()
                            .focused($isFocused)
                        //                            .disabled(vm.isRunning)
                            .onSubmit {
                                //                                if (!vm.isRunning && vm.modelContainer != nil && vm.downloadFraction != 0) {
                                Task {
                                    await generate(isWebSearch: isWebSearch)
                                }
                            }
                    }
                    
                    HStack {
                        Button {
                            isWebSearch.toggle()
                        } label: {
                            Image(systemName: "network")
                                .foregroundColor(isWebSearch ? .accentColor : .secondary)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .padding(8)
                        
                        Spacer()
                        
                        Button {
                            Task {
                                await generate(isWebSearch: isWebSearch)
                            }
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .fontWeight(.medium)
                        }
                        .padding()
                    }
                    .padding([.trailing, .leading])
                }
            }
            .glassEffect(in: .rect(cornerRadius: 16.0))
            .padding()
        }
    }
    
    private func generate(isWebSearch: Bool) async {
        isFocused = false
        withAnimation {
            vm.chat.append(.user(prompt))
            prompt = ""
            vm.chat.append(.assistant("Thinking..."))
        }
        
        print("[DEBUG] \(isWebSearch)")
        do {
            try await vm.generateResponse(from: vm.chat)
        } catch {
            print("[DEBUG] Error: \(error.localizedDescription)")
        }
//        await vm.generate(messages: vm.chat, includeWebSearch: isWebSearch)
        StatusManager.shared.clearStatus()
    }
}

#Preview {
    @Previewable @State var vm = LLM()
    @Previewable @State var prompt: String = ""
    BottomBar(vm: $vm, prompt: $prompt)
}
