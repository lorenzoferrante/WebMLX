//
//  MessageView.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 7/25/25.
//

import SwiftUI
import MLXLMCommon

struct MessageView: View {
    @State var message: Chat.Message
    
    var body: some View {
        VStack {
            switch message.role {
            case .assistant:
                Text(.init(message.content))
                    .fontDesign(.serif)
                    .padding(10)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .glassEffect(in: .rect(cornerRadius: 16))
            case .user:
                Text(.init(message.content))
                    .padding(10)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .trailing
                    )
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    @Previewable @State var message: Chat.Message = .init(role: .user, content: "Hello!")
    MessageView(message: message)
}
