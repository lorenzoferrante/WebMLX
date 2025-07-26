//
//  ChatView.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 7/25/25.
//

import SwiftUI
import MLXLMCommon

struct ChatView: View {
    @Binding var vm: MLXViewModel
    
    private var lastMessageContent: String {
        vm.chat.last?.content ?? ""
    }
    
    private let bottomID = "bottomID"
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ForEach(vm.chat, id: \.content) { message in
                    MessageView(message: message)
                        .padding([.trailing, .leading])
                }
                Color.clear
                    .frame(height: 1)
                    .id(bottomID)
            }
            .onChange(of: lastMessageContent) { _, _ in
                withAnimation {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var vm = MLXViewModel()
    ChatView(vm: $vm)
        .onAppear {
            vm.chat.append(contentsOf: [
                .init(role: .user, content: "Hello!"),
                .init(role: .assistant, content: "I am an LLM developed by DMP! How can I help you?")
            ])
        }
}
