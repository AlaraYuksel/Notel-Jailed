//
//  ProviderLayer.swift
//  Notel
//
//  Created by Alara yüksel on 17.05.2025.
//

import SwiftUI
import PencilKit

/*
// MARK: - ZoomableView: Sadece çift parmak zoom özelliği
struct ZoomableView<Content: View>: UIViewRepresentable {
    let content: Content
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    
    init(scale: Binding<CGFloat>, offset: Binding<CGSize>, @ViewBuilder content: () -> Content) {
        self._scale = scale
        self._offset = offset
        self.content = content()
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 3.0
        scrollView.zoomScale = scale
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = true
        scrollView.bouncesZoom = true
        
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
        ])
        
        context.coordinator.hostingController = hostingController
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        if abs(uiView.zoomScale - scale) > 0.01 {
            uiView.zoomScale = scale
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableView
        var hostingController: UIHostingController<Content>?
        
        init(_ parent: ZoomableView) {
            self.parent = parent
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController?.view
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            parent.scale = scrollView.zoomScale
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            parent.offset = CGSize(
                width: scrollView.contentOffset.x,
                height: scrollView.contentOffset.y
            )
        }
    }
}*/

// MARK: - Draggable Toolbar
struct DraggableToolbar: View {
    @State private var position = CGPoint(x: 100, y: 100)
    @State private var isExpanded = false
    @GestureState private var dragOffset = CGSize.zero
    @ObservedObject var toolSettings: ToolSettings 
    // PDF Import için
    @Binding var showPDFImporter: Bool
    let onPDFImport: (Result<[URL], Error>) -> Void
    @Binding var currentTool: PKTool
    @Binding var showPalette: Bool
    // Toolbar actions
    let onImagePicker: () -> Void
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onPlayRecording: () -> Void
    let onStopPlayback: () -> Void
    let onSelectPen: () -> Void
    let onSelectEraser: () -> Void
    let onSelectHighlighter: () -> Void
    let onSelectBrush: () -> Void
    let onDeleteAll: () -> Void
    let onAddPage: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onOpenSheet:()->Void
    let onClickEdit:()->Void
    let onSelectLasso:()->Void
    // States
    let isRecording: Bool
    let isPlaying: Bool
    let canUndo: Bool
    let canRedo: Bool
    let hasRecordings: Bool
    let selectedTool: String // "pen", "eraser", "highlighter", "brush"
    
    var body: some View {
        VStack(spacing: 0) {
            // Ana toolbar - her zaman görünür
            HStack(spacing: 12) {
                // Expand/Collapse butonu
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.blue.opacity(0.8))
                        .clipShape(Circle())
                }
                
                // En önemli araçlar - her zaman görünür
                toolButton(
                    icon: selectedTool == "pen" ? "pencil.tip.crop.circle.badge.plus" : "pencil.tip",
                    isSelected: selectedTool == "pen",
                    action: onSelectPen
                    
                )// Located in DraggableToolbar (NotePageView.swift)
                // Around Page 4, inside the .popover modifier for the pen's toolButton

                .popover(isPresented: $showPalette) {
                    // Bu blok, kalem aracı için palet (DrawingToolPaletteView) gösterildiğinde çalışır.
                    // Paletin, `currentTool`'u (yani aktif kalemi) değiştirebilmesi için ona bir "Binding" verilir.
                    
                    // Emin olalım ki `currentTool` gerçekten bir PKInkingTool ve tipi .pen.
                    if let inkingTool = currentTool as? PKInkingTool, inkingTool.inkType == .pen { // [cite: 9, 10]
                        DrawingToolPaletteView(currentTool: Binding( // [cite: 10]
                            // GET bloğu: Palet, kalemin o anki ayarlarını okumak istediğinde çalışır.
                            get: { inkingTool },
                            
                            // SET bloğu: Palet, kalemin rengini veya kalınlığını değiştirdiğinde çalışır.
                            set: { newToolSettingsFromPalette in
                                // newToolSettingsFromPalette, paletten gelen yeni renk/kalınlık ayarlarını içeren kalemdir.

                                // Adım 1: Aktif aracı (currentTool) paletten gelen yeni ayarlarla güncelle.
                                currentTool = newToolSettingsFromPalette // Bu, NotePageView'deki @State currentTool'u günceller.

                                // Adım 2: KRİTİK DÜZELTME: Kalemin "özel hafıza kutusunu" (`toolSettings.lastPenTool`) da güncelle.
                                // Eğer paletten gelen aracın tipi hala .pen ise (ki öyle olmalı),
                                // bu yeni ayarları `toolSettings.lastPenTool`'a kaydet.
                                if newToolSettingsFromPalette.inkType == .pen {
                                    toolSettings.lastPenTool = newToolSettingsFromPalette // Değişikliği hafızaya kaydet. [cite: 71]
                                    
                                    // İsteğe Bağlı Hata Ayıklama:
                                    if let pen = toolSettings.lastPenTool as? PKInkingTool {
                                        print("Kalem paletinden ayarlar güncellendi. Yeni saklanan renk: \(pen.color), kalınlık: \(pen.width)")
                                    }
                                }
                            }
                        ))
                    }
                }
                toolButton(
                    icon: selectedTool == "eraser" ? "eraser.fill" : "eraser",
                    isSelected: selectedTool == "eraser",
                    action: onSelectEraser
                )
                
                toolButton(
                    icon: "arrow.uturn.backward",
                    isSelected: false,
                    isEnabled: canUndo,
                    action: onUndo
                )
                
                toolButton(
                    icon: "arrow.uturn.forward",
                    isSelected: false,
                    isEnabled: canRedo,
                    action: onRedo
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            )
            
            // Genişletilmiş araçlar
            if isExpanded {
                VStack(spacing: 8) {
                    // İkinci sıra
                    HStack(spacing: 12) {
                        toolButton(
                            icon: selectedTool == "highlighter" ? "highlighter" : "highlighter",
                            isSelected: selectedTool == "highlighter",
                            action: onSelectHighlighter
                        )
                        
                        toolButton(
                            icon: selectedTool == "brush" ? "paintbrush.fill" : "paintbrush",
                            isSelected: selectedTool == "brush",
                            action: onSelectBrush
                        )
                        toolButton(
                            icon: selectedTool == "lasso" ? "lasso" : "lasso",
                            isSelected: selectedTool == "lasso",
                            action: onSelectLasso
                        )
                        toolButton(
                            icon: "photo.badge.plus",
                            isSelected: false,
                            color: .orange,
                            action: onImagePicker
                        )
                        
                        toolButton(
                            icon: "plus.circle.fill",
                            isSelected: false,
                            color: .green,
                            action: onAddPage
                        )
                                            }
                    
                    // Üçüncü sıra - Ses kontrolleri
                    HStack(spacing: 12) {
                        toolButton(
                            icon: isRecording ? "mic.fill.badge.xmark" : "mic.fill",
                            isSelected: isRecording,
                            color: isRecording ? .red : .blue,
                            isEnabled: !isPlaying,
                            action: isRecording ? onStopRecording : onStartRecording
                        )
                        /*
                        toolButton(
                            icon: isPlaying ? "stop.circle.fill" : "play.circle.fill",
                            isSelected: isPlaying,
                            color: .yellow,
                            isEnabled: hasRecordings && !isRecording,
                            action: isPlaying ? onStopPlayback : onPlayRecording
                        )*/
                        
                        toolButton(
                            icon: isPlaying ? "stop.circle.fill" : "play.circle.fill",
                            isSelected: isPlaying,
                            color: .yellow,
                            isEnabled: hasRecordings && !isRecording,
                            action: onOpenSheet
                        )
                        
                        toolButton(
                            icon: "trash.fill",
                            isSelected: false,
                            color: .red,
                            action: onDeleteAll
                        )
                        toolButton(
                            icon: "photo.circle.fill",
                            isSelected: false,
                            color: .pink,
                            action: onClickEdit
                        )

                        toolButton(
                                                    icon: "doc.fill",
                                                    isSelected: false,
                                                    color: .purple,
                                                    action: { showPDFImporter = true }
                                                )
                                                .fileImporter(
                                                    isPresented: $showPDFImporter,
                                                    allowedContentTypes: [.pdf],
                                                    allowsMultipleSelection: false,
                                                    onCompletion: onPDFImport
                                                )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .padding(.top, 8)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.8)).combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.8))
                ))
            }
        }
        .position(x: position.x + dragOffset.width, y: position.y + dragOffset.height)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    position.x += value.translation.width // Changed from .x to .width
                    position.y += value.translation.height // Changed from .y to .height

                    // Ekran sınırları içinde kalmasını sağla
                    let screenBounds = UIScreen.main.bounds
                    position.x = max(50, min(position.x, screenBounds.width - 50))
                    position.y = max(50, min(position.y, screenBounds.height - 300))
                }
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
    }
    
    // Yardımcı buton oluşturucu
    private func toolButton(
        icon: String,
        isSelected: Bool,
        color: Color = .blue,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isEnabled ? .white : .gray)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(isSelected ? color : color.opacity(0.6))
                        .overlay(
                            Circle()
                                .stroke(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 2)
                        )
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

/*
import SwiftUI

struct ToolButton: View {
    let icon: String
    var isSelected: Bool = false
    var color: Color = .black // Varsayılan renk
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isSelected ? .white : color)
                .padding(10)
                .background(isSelected ? Color.blue : Color.clear)
                .clipShape(Circle())
        }
    }
}
*/
