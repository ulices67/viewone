import SwiftUI
import ReplayKit

/// Envuelve el selector oficial del sistema iOS para grabación / transmisión de pantalla completa
public struct SystemBroadcastPicker: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        picker.preferredExtension = nil
        picker.showsMicrophoneButton = false

        // Personalización del botón del sistema
        for subview in picker.subviews {
            if let button = subview as? UIButton {
                button.tintColor = .systemBlue
            }
        }

        return picker
    }

    public func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
