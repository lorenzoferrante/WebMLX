//
//  BottomBar.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 7/25/25.
//

import SwiftUI
import MLXLMCommon

struct BottomBar: View {
    @Binding var vm: MLXViewModel
    @Binding var prompt: String
    
    @FocusState private var isFocused: Bool
    
    @State var isWebSearch: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            
            GlassEffectContainer {
                VStack(alignment: .leading) {
                    if vm.downloadProgress != nil {
                        if vm.downloadProgress?.isFinished == false {
                            Text("Downloading model: \(vm.downloadFraction * 100, specifier: "%.1f")%")
                                .font(.caption)
                                .padding([.top, .leading, .trailing])
                                .foregroundStyle(.secondary)
                        }
                    } else if vm.errorMessage != nil {
                        Text("Error: \(vm.errorMessage!)")
                            .font(.caption)
                            .padding([.top, .leading, .trailing])
                            .foregroundStyle(.red)
                    }
                    
                    VStack {
                        TextField("Ask anything...", text: $prompt)
                            .padding()
                            .focused($isFocused)
                            .disabled(vm.isRunning)
                            .onSubmit {
                                Task {
                                    await generate(isWebSearch: isWebSearch)
                                }
                            }
                        
                        HStack {
                            Button {
                                isWebSearch.toggle()
                            } label: {
                                Image(systemName: "network")
                            }
                            .tint(isWebSearch ? Color.accentColor : Color.secondary)

                            Spacer()
                            
                            if vm.isRunning {
                                ProgressView()
                                    .padding()
                            } else {
                                Button {
                                    Task {
                                        await generate(isWebSearch: isWebSearch)
                                    }
                                } label: {
                                    Image(systemName: "paperplane.fill")
                                }
                                .padding()
                                .disabled(vm.isRunning)
                            }
                        }
                        .padding([.trailing, .leading])
                    }
                }
                .glassEffect(in: .rect(cornerRadius: 16.0))
                .padding()
            }
        }
    }
    
    private func generate(isWebSearch: Bool) async {
        isFocused = false
        withAnimation {
            vm.chat.append(.user(prompt))
            prompt = ""
            vm.chat.append(.assistant("Generating..."))
        }
        
        await vm.generate(messages: vm.chat, includeWebSearch: isWebSearch)
    }
}

#Preview {
    @Previewable @State var vm = MLXViewModel()
    @Previewable @State var prompt: String = ""
    BottomBar(vm: $vm, prompt: $prompt)
}
