import Foundation
import SwiftUI
import PencilKit
struct DrawingToolPaletteView: View {
    @Binding var currentTool: PKInkingTool
    @State private var selectedColor: Color = .black
    @State private var selectedWidth: CGFloat = 5
    let widths: [CGFloat] = [2, 5, 8, 12]
    var body: some View {
        VStack(alignment: .leading) {
            Text("Renk Seç").font(.headline)
            // SwiftUI ColorPicker
            ColorPicker("Renk Seç", selection: $selectedColor)
                .labelsHidden()
                .onChange(of: selectedColor) { newColor in
                    guard currentTool.inkType == .pen else { return }
                    let uiColor = UIColor(newColor)
                    updateTool(color: uiColor, width: selectedWidth)
                }
            Divider().padding(.vertical, 8)
            Text("Kalınlık").font(.headline)
            HStack {
                ForEach(widths, id: \.self) { width in
                    Circle()
                        .fill(selectedColor)
                        .frame(width: width + 10, height: width + 10)
                        .overlay(
                            Circle()
                                .stroke(selectedWidth == width ? Color.gray : Color.clear, lineWidth: 2)
                        )
                        .onTapGesture {
                            selectedWidth = width
                            updateTool(color: UIColor(selectedColor), width: width)
                        }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(radius: 5)
        .onAppear {
            // İlk değerleri eşitle
            selectedColor = Color(currentTool.color)
            selectedWidth = currentTool.width
        }
        
    }
    func updateTool(color: UIColor, width: CGFloat) {
        currentTool = PKInkingTool(currentTool.inkType, color: color, width: width)
    }
}
