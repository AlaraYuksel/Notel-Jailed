//
//  ZoomSettings.swift
//  Notel
//
//  Created by Alara yüksel on 17.05.2025.
//
/*
import Foundation
import SwiftUI

// ZoomableView - Büyültme ve kaydırma özelliğini sağlayan struct
struct ZoomableView<Content: View>: View {
    let minScale: CGFloat
    let maxScale: CGFloat
    @ViewBuilder let content: () -> Content
    
    @State private var currentScale: CGFloat = 1.0
    @State private var dragOffset = CGSize.zero
    @State private var lastDragValue = CGSize.zero
    
    var body: some View {
        content()
            .scaleEffect(currentScale)
            .offset(dragOffset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / currentScale
                        currentScale = min(max(currentScale * delta, minScale), maxScale)
                    }
            )
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let translation = CGSize(
                            width: lastDragValue.width + gesture.translation.width,
                            height: lastDragValue.height + gesture.translation.height
                        )
                        dragOffset = translation
                    }
                    .onEnded { gesture in
                        lastDragValue = dragOffset
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        if currentScale > minScale {
                            withAnimation(.spring()) {
                                currentScale = minScale
                                dragOffset = .zero
                                lastDragValue = .zero
                            }
                        } else {
                            withAnimation(.spring()) {
                                currentScale = min(currentScale * 2, maxScale)
                            }
                        }
                    }
            )
    }
}

// Zoom kontrolleri için opsiyonel bir view
struct ZoomControls: View {
    @EnvironmentObject var zoomState: ZoomState
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: {
                withAnimation {
                    zoomState.decreaseZoom()
                }
            }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 20))
                    .padding(8)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Circle())
                    .shadow(radius: 2)
            }
            
            Button(action: {
                withAnimation {
                    zoomState.resetZoom()
                }
            }) {
                Image(systemName: "1.magnifyingglass")
                    .font(.system(size: 20))
                    .padding(8)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Circle())
                    .shadow(radius: 2)
            }
            
            Button(action: {
                withAnimation {
                    zoomState.increaseZoom()
                }
            }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 20))
                    .padding(8)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Circle())
                    .shadow(radius: 2)
            }
        }
    }
}

// Zoom state'i yönetmek için EnvironmentObject
class ZoomState: ObservableObject {
    @Published var scale: CGFloat = 1.0
    let minScale: CGFloat = 1.0
    let maxScale: CGFloat = 5.0
    let zoomStep: CGFloat = 0.25
    
    func increaseZoom() {
        scale = min(scale + zoomStep, maxScale)
    }
    
    func decreaseZoom() {
        scale = max(scale - zoomStep, minScale)
    }
    
    func resetZoom() {
        scale = 1.0
    }
}
*/
