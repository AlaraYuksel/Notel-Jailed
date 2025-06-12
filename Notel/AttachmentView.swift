//
//  AttachmentView.swift
//  Notel
//
//  Created by Alara yüksel on 24.04.2025.
//
//

import SwiftUI
import CoreData
import PencilKit

struct AttachmentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var attachment: Attachment
    
    var onMoveEnded: ((UUID, Float, Float, Float, Float) -> Void)?

    @State private var dragOffset: CGSize = .zero
    @State private var isEditing = false
    @State private var currentWidth: CGFloat = 0
    @State private var currentHeight: CGFloat = 0
    @State private var attachmentCanvasView = PKCanvasView()

    
    var body: some View {
        ZStack {
            if let imageData = attachment.fileData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: currentWidth, height: currentHeight)
                    .offset(dragOffset)
                    .onTapGesture {
                        withAnimation {
                            isEditing.toggle()
                        }
                    }
                    .border(isEditing ? Color.blue : Color.clear, width: 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                self.dragOffset = value.translation
                            }
                            .onEnded { value in
                                let finalX = attachment.positionX + Float(value.translation.width)
                                let finalY = attachment.positionY + Float(value.translation.height)
                                
                                let oldX = attachment.positionX
                                let oldY = attachment.positionY

                                attachment.positionX = finalX
                                attachment.positionY = finalY
                                
                                saveContext()
                                dragOffset = .zero
                                
                                if let id = attachment.id {
                                    onMoveEnded?(id, oldX, oldY, finalX, finalY)
                                }
                            }
                    )
                
                if isEditing {
                    ResizeHandles(currentWidth: $currentWidth, currentHeight: $currentHeight) {
                        saveSizeChanges()
                    }
                }
            } else {
                Text("Resim Yüklenemedi")
                    .foregroundColor(.red)
                    .frame(width: CGFloat(attachment.width), height: CGFloat(attachment.height))
                    .background(Color.gray.opacity(0.2))
            }
            
            
        }
        .onAppear {
            currentWidth = CGFloat(attachment.width)
            currentHeight = CGFloat(attachment.height)
        }
    }
    
    private func saveContext() {
        do {
            if viewContext.hasChanges {
                try viewContext.performAndWait {
                    try viewContext.save()
                    print("Changes saved.")
                }
            }
        } catch {
            print("Error saving context: \(error.localizedDescription)")
            viewContext.rollback()
        }
    }
    
    private func saveSizeChanges() {
        attachment.width = Float(currentWidth)
        attachment.height = Float(currentHeight)
        saveContext()
    }
}

// Bu component köşe noktalarını oluşturur
struct ResizeHandles: View {
    @Binding var currentWidth: CGFloat
    @Binding var currentHeight: CGFloat
    var onResizeEnded: () -> Void
    
    var body: some View {
        ZStack {
            // Sağ Alt köşe (bottom right)
            Circle()
                .fill(Color.blue)
                .frame(width: 20, height: 20)
                .position(x: currentWidth, y: currentHeight)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newWidth = max(50, value.location.x) // min 50
                            let newHeight = max(50, value.location.y) // min 50
                            currentWidth = newWidth
                            currentHeight = newHeight
                        }
                        .onEnded { _ in
                            onResizeEnded()
                        }
                )
        }
    }
}

