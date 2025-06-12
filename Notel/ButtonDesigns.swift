//
//  ButtonDesigns.swift
//  Notel
//
//  Created by Alara yüksel on 17.05.2025.
//

import Foundation
import SwiftUI
import PDFKit

struct PDFImporterButton: View {
    @Binding var showPDFImporter: Bool
    var onImport: (Result<[URL], Error>) -> Void
    
    var body: some View {
        Button(action: {
            showPDFImporter = true
        }) {
            HStack {
                Image(systemName: "doc.fill")
                    .font(.system(size: 16, weight: .medium))
                Text("PDF Ekle")
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .fileImporter(
            isPresented: $showPDFImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            onImport(result)
        }
    }
}
