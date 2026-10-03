import SwiftUI

public struct QuickCaptureView: View {
    @ObservedObject private var engine = CaptureEngine.shared
    @ObservedObject private var vaultManager = VaultManager.shared

    @State private var showingSavedAlert = false
    @State private var lastItemCaptured: CapturedItem?
    @State private var isProcessingCapture = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Status Header
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(engine.isRecording ? Color.green : Color.orange)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(engine.isRecording ? Color.green : Color.orange, lineWidth: 2)
                                    .scaleEffect(engine.isRecording ? 1.6 : 1.0)
                                    .opacity(engine.isRecording ? 0.4 : 0.0)
                                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: engine.isRecording)
                            )

                        Text(engine.isRecording ? "Capture Session Active" : "Ready to Capture")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    Text("El asistente retiene únicamente el último frame en memoria volátil.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 16)

                Spacer()

                // Big Capture Trigger Button
                VStack(spacing: 16) {
                    Button {
                        triggerCapture()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.blue.opacity(0.3), lineWidth: 6)
                                .frame(width: 160, height: 160)

                            Circle()
                                .fill(LinearGradient(colors: [Color.blue, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 136, height: 136)
                                .shadow(color: Color.blue.opacity(0.4), radius: 16, x: 0, y: 8)

                            VStack(spacing: 6) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)

                                Text("CAPTURE")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .tracking(2)
                            }
                        }
                    }
                    .disabled(isProcessingCapture)
                    .scaleEffect(isProcessingCapture ? 0.94 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isProcessingCapture)

                    // Session Toggle Button
                    Button {
                        if engine.isRecording {
                            engine.stopCaptureSession()
                        } else {
                            engine.startCaptureSession()
                        }
                    } label: {
                        Label(
                            engine.isRecording ? "Detener Sesión Autorizada" : "Iniciar Sesión de Captura",
                            systemImage: engine.isRecording ? "stop.circle.fill" : "record.circle"
                        )
                        .font(.subheadline.bold())
                        .foregroundColor(engine.isRecording ? .red : .blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(engine.isRecording ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                Spacer()

                // Last Capture and Settings Card
                VStack(spacing: 14) {
                    if let time = engine.lastCaptureTime {
                        HStack {
                            Image(systemName: "clock.badge.checkmark")
                                .foregroundColor(.green)
                            Text("Última captura:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(time, style: .time)
                                .font(.subheadline.monospacedDigit().bold())
                        }
                        Divider()
                    }

                    Toggle(isOn: $engine.autoDelete24h) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Eliminar tras 24 horas")
                                .font(.subheadline.weight(.semibold))
                            Text("Las capturas no marcadas como fijas expiran automáticamente")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Protection Notice
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.subheadline)
                            .foregroundColor(.indigo)

                        Text("Respeto de privacidad del sistema: Si una app o iOS protege una superficie (ej. contenido View-Once o DRM), el compositor de Apple devolverá un frame en negro.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(18)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle("Quick Capture")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $lastItemCaptured) { item in
                NavigationStack {
                    DetailCaptureView(item: item)
                }
            }
        }
    }

    private func triggerCapture() {
        isProcessingCapture = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            if let captured = await engine.captureCurrentFrame() {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                self.lastItemCaptured = captured
            }
            self.isProcessingCapture = false
        }
    }
}
