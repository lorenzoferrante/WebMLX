//
//  ModelSelectorView.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 14/07/25.
//

import SwiftUI

struct ModelSelectorView: View {
    @Binding var vm: MLXViewModel
    @State var selection: CustomModels = .llama3_2_3B_4bit
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(selection: $selection) {
                        ForEach(CustomModels.allCases, id: \.self) { model in
                            Text(model.rawValue)
                        }
                    } label: {
                        Text("Select a model:")
                    }
                    
                    Button {
                        loadModel()
                    } label: {
                        Text("Load selected model")
                    }

                }
                
                if vm.downloadProgress != nil {
                    Section("Downloading model...") {
                        VStack(alignment: .leading) {
                            Text("Download progress: \(vm.downloadFraction * 100, specifier: "%.1f")%")
                            ProgressView(value: vm.downloadFraction, total: 1.0)
                        }
                    }
                }
            }
        }
    }
    
    private func loadModel() {
        vm.setModelConfiguration(selection.modelConfiguration())
        Task {
            await vm.loadModel()
        }
    }
}

#Preview {
    @Previewable @State var vm = MLXViewModel()
    ModelSelectorView(vm: $vm)
}
