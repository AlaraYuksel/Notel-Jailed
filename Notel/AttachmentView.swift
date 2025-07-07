import SwiftUI
import CoreData
import PencilKit

struct AttachmentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var attachment: Attachment
    
    var onMoveEnded: ((UUID, Float, Float, Float, Float) -> Void)?
    // Add a closure for when the attachment is deleted
    var onDelete: ((UUID) -> Void)?

    @State private var dragOffset: CGSize = .zero
    @State private var isEditing = false
    @State private var currentWidth: CGFloat = 0
    @State private var currentHeight: CGFloat = 0
    // private var attachmentCanvasView = PKCanvasView() // This line seems unused

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
                    // Resize Handles
                    ResizeHandles(
                        currentWidth: $currentWidth,
                        currentHeight: $currentHeight,
                        imageSize: CGSize(width: currentWidth, height: currentHeight)
                    ) {
                        saveSizeChanges()
                    }
                    
                    // Delete Button
                    Button(action: {
                        deleteAttachment()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                            .background(Circle().fill(Color.white))
                            .shadow(radius: 5)
                    }
                    // Position the delete button (e.g., top-right corner of the attachment)
                    .offset(x: (currentWidth / 2) + 4, y: (-currentHeight / 2) - 4)
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
            // Initialize dragOffset based on attachment's position if needed for initial placement
            // dragOffset = CGSize(width: CGFloat(attachment.positionX), height: CGFloat(attachment.positionY))
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
    
    private func deleteAttachment() {
        if let id = attachment.id {
            viewContext.delete(attachment)
            saveContext()
            onDelete?(id) // Notify parent view of deletion
        }
    }
}

// Düzeltilmiş ResizeHandles component'i
struct ResizeHandles: View {
    @Binding var currentWidth: CGFloat
    @Binding var currentHeight: CGFloat
    let imageSize: CGSize
    var onResizeEnded: () -> Void
    
    private let handleSize: CGFloat = 20
    
    var body: some View {
        // Handle'ları resmin tam boyutunda bir overlay olarak konumlandır
        Rectangle()
            .fill(Color.clear)
            .frame(width: imageSize.width, height: imageSize.height)
            .overlay(
                ZStack {
                    // Köşe handle'ları
                    Group {
                        // Sol Üst köşe
                        ResizeHandle(type: .topLeft) { delta in
                            let newWidth = max(50, currentWidth - delta.width)
                            let newHeight = max(50, currentHeight - delta.height)
                            currentWidth = newWidth
                            currentHeight = newHeight
                        } onEnded: {
                            onResizeEnded()
                        }
                        .offset(x: -imageSize.width/2 + handleSize/2, y: -imageSize.height/2 + handleSize/2)
                        
                        // Sağ Üst köşe
                        ResizeHandle(type: .topRight) { delta in
                            let newWidth = max(50, currentWidth + delta.width)
                            let newHeight = max(50, currentHeight - delta.height)
                            currentWidth = newWidth
                            currentHeight = newHeight
                        } onEnded: {
                            onResizeEnded()
                        }
                        .offset(x: imageSize.width/2 - handleSize/2, y: -imageSize.height/2 + handleSize/2)
                        
                        // Sol Alt köşe
                        ResizeHandle(type: .bottomLeft) { delta in
                            let newWidth = max(50, currentWidth - delta.width)
                            let newHeight = max(50, currentHeight + delta.height)
                            currentWidth = newWidth
                            currentHeight = newHeight
                        } onEnded: {
                            onResizeEnded()
                        }
                        .offset(x: -imageSize.width/2 + handleSize/2, y: imageSize.height/2 - handleSize/2)
                        
                        // Sağ Alt köşe
                        ResizeHandle(type: .bottomRight) { delta in
                            let newWidth = max(50, currentWidth + delta.width)
                            let newHeight = max(50, currentHeight + delta.height)
                            currentWidth = newWidth
                            currentHeight = newHeight
                        } onEnded: {
                            onResizeEnded()
                        }
                        .offset(x: imageSize.width/2 - handleSize/2, y: imageSize.height/2 - handleSize/2)
                    }
                    
                    // Kenar handle'ları
                    Group {
                        // Üst kenar
                        ResizeHandle(type: .top) { delta in
                            let newHeight = max(50, currentHeight - delta.height)
                            currentHeight = newHeight
                        } onEnded: {
                            onResizeEnded()
                        }
                        .offset(x: 0, y: -imageSize.height/2 + handleSize/2)
                        
                        // Alt kenar
                        ResizeHandle(type: .bottom) { delta in
                            let newHeight = max(50, currentHeight + delta.height)
                            currentHeight = newHeight
                        } onEnded: {
                            onResizeEnded()
                        }
                        .offset(x: 0, y: imageSize.height/2 - handleSize/2)
                        
                        // Sol kenar
                        ResizeHandle(type: .left) { delta in
                            let newWidth = max(50, currentWidth - delta.width)
                            currentWidth = newWidth
                        } onEnded: {
                            onResizeEnded()
                        }
                        .offset(x: -imageSize.width/2 + handleSize/2, y: 0)
                        
                        // Sağ kenar
                        ResizeHandle(type: .right) { delta in
                            let newWidth = max(50, currentWidth + delta.width)
                            currentWidth = newWidth
                        } onEnded: {
                            onResizeEnded()
                        }
                        .offset(x: imageSize.width/2 - handleSize/2, y: 0)
                    }
                }
            )
    }
}

// Handle türleri
enum ResizeHandleType {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight
    
    var cursor: String {
        switch self {
        case .topLeft, .bottomRight: return "nw-resize"
        case .topRight, .bottomLeft: return "ne-resize"
        case .top, .bottom: return "n-resize"
        case .left, .right: return "e-resize"
        }
    }
    
    var color: Color {
        switch self {
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            return .blue
        case .top, .bottom, .left, .right:
            return .green
        }
    }
}

// Düzeltilmiş ResizeHandle
struct ResizeHandle: View {
    let type: ResizeHandleType
    let onChanged: (CGSize) -> Void
    let onEnded: () -> Void
    
    private let handleSize: CGFloat = 20
    
    var body: some View {
        Circle()
            .fill(type.color)
            .frame(width: handleSize, height: handleSize)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(radius: 2)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        onChanged(value.translation)
                    }
                    .onEnded { _ in
                        onEnded()
                    }
            )
    }
}
