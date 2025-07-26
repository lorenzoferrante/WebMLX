//
//  StatusView.swift
//  MLXTest
//
//  Created by Lorenzo Ferrante on 26/07/25.
//

import SwiftUI

struct StatusView: View {
    @State var statusManager = StatusManager.shared
    
    var body: some View {
        VStack(alignment: .center) {
            if statusManager.status != "" {
                Text(statusManager.status)
                    .padding()
                    .glassEffect()
            } else {
                EmptyView()
            }
            Spacer()
        }
        .padding()
    }
}

#Preview {
    StatusView()
        .onAppear {
            StatusManager.shared.setStatus(to: "Hello world!")
        }
}
