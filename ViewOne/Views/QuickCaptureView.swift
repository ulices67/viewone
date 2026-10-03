import SwiftUI
import ReplayKit

public struct QuickCaptureView: View {
    @ObservedObject private var engine = CaptureEngine.shared
    @ObservedObject private var vaultManager = VaultManager.shared
    @ObservedObject private var observer = ScreenshotObserver.shared

    @State private var showingSavedAlert = false
    @State private var lastItemCaptured: CapturedItem?
    @State private var isProcessingCapture = false
    @State private var countdownRemaining: Int = 0
    @State private var isCountdownActive = false
    @State private var showHowToGuide = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Status
                    statusBanner

                    // Explanation Callout (Por qué se capturaba ViewOne y cómo capturar otras apps)
                    explanationCallout

                    // Capture Methods Section
                    captureMethodsSection

                    // Expiration & Privacy Settings
                    settingsCard
                }
                .padding(.vertical)
            }
            .navigationTitle("Capture Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $lastItemCaptured) { item in
                NavigationStack {
                    DetailCaptureView(item: item)
                }
            }
            .sheet(isPresented: $showHowToGuide) {
                backTapGuideSheet
            }
        }
    }

    // MARK: - Status Banner
    private var statusBanner: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(engine.isRecording ? Color.green : Color.blue)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .stroke(engine.isRecording ? Color.green : Color.blue, lineWidth: 2)
                        .scaleEffect(engine.isRecording ? 1.6 : 1.2)
                        .opacity(engine.isRecording ? 0.4 : 0.2)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: engine.isRecording)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(engine.isRecording ? "Sesión del Sistema Activa" : "Asistente Listo")
                    .font(.subheadline.bold())
                Text("Monitoreo de capturas activado")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let time = engine.lastCaptureTime {
                Text(time, style: .time)
                    .font(.caption.monospacedDigit().bold())
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Explanation Callout
    private var explanationCallout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("¿Cómo capturar dentro de WhatsApp o Instagram?")
                    .font(.subheadline.bold())
            }

            Text("Por seguridad, iOS no permite que una app dibuje botones flotantes sobre otra app. Para capturar contenido de otras aplicaciones tienes 2 métodos:")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button {
                    showHowToGuide = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                        Text("Activar 'Tocar Atrás'")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
                }

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gear")
                        Text("Ajustes del iPhone")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.12))
                    .foregroundColor(.primary)
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Capture Methods Section
    private var captureMethodsSection: some View {
        VStack(spacing: 18) {
            // Option 1: Back Tap & Physical Button (Primary)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Método 1: Captura Nativa (Recomendada)", systemImage: "hand.tap.fill")
                        .font(.headline)
                    Spacer()
                    Text("Automático")
                        .font(.caption2.bold())
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                }

                Text("Abre WhatsApp, Instagram o Safari y pulsa **Botón Lateral + Volumen Arriba** (o dale 2 toques a la parte trasera de tu iPhone). ViewOne la detectará al instante y la clasificará con Vision OCR.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No necesitas tener ViewOne abierta en primer plano.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)

            // Option 2: Countdown Timer to switch apps
            VStack(alignment: .leading, spacing: 12) {
                Label("Método 2: Temporizador para cambiar de App", systemImage: "timer")
                    .font(.headline)

                Text("Te da 5 segundos para salir de ViewOne y colocarte en WhatsApp, Instagram o Safari antes de guardar la captura:")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                if isCountdownActive {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Text("\(countdownRemaining)")
                                .font(.system(size: 48, weight: .heavy, design: .rounded))
                                .foregroundColor(.orange)
                            Text("¡Cambia a tu otra app ahora!")
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                        }
                        Spacer()
                    }
                    .padding()
                } else {
                    Button {
                        startCountdown()
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Iniciar Cuenta Atrás (5 segundos)")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)

            // Option 3: System Broadcast Picker (Official Screen Recorder)
            VStack(alignment: .leading, spacing: 12) {
                Label("Método 3: Selector de Grabación del Sistema", systemImage: "record.circle")
                    .font(.headline)

                Text("Abre el selector oficial de pantalla de Apple para emitir el contenido completo del sistema:")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selector Oficial ReplayKit")
                            .font(.caption.bold())
                        Text("Toca para abrir el panel nativo de iOS")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    SystemBroadcastPicker()
                        .frame(width: 50, height: 50)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }

    // MARK: - Settings & Auto-delete
    private var settingsCard: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $engine.autoDelete24h) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Eliminar capturas tras 24 horas")
                        .font(.subheadline.weight(.semibold))
                    Text("Las capturas no fijadas caducan automáticamente de la bóveda")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.caption)
                    .foregroundColor(.indigo)
                Text("Las superficies protegidas por iOS (DRM, View-Once de WhatsApp) se ocultan como pantalla en negro por el sistema.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Guide Sheet
    private var backTapGuideSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Cómo activar 'Tocar Atrás' en iPhone")
                    .font(.title2.bold())

                Text("Esta es la forma más rápida y cómoda de hacer capturas en cualquier app sin que se vea ViewOne:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 14) {
                    guideStep(num: "1", title: "Abre Ajustes", desc: "Ve a la app de Ajustes de tu iPhone.")
                    guideStep(num: "2", title: "Accesibilidad", desc: "Selecciona 'Accesibilidad' y luego 'Tocar'.")
                    guideStep(num: "3", title: "Tocar atrás", desc: "Baja hasta el final y toca 'Tocar atrás'.")
                    guideStep(num: "4", title: "Pulsar dos veces", desc: "Selecciona 'Captura de pantalla'.")
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)

                Text("¡Listo! Cada vez que des dos toques con el dedo en la parte trasera del iPhone dentro de WhatsApp o Instagram, se tomará la captura y ViewOne la organizará automáticamente.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    showHowToGuide = false
                } label: {
                    Text("Entendido")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func guideStep(num: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(num)
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Countdown Action
    private func startCountdown() {
        countdownRemaining = 5
        isCountdownActive = true

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdownRemaining > 1 {
                countdownRemaining -= 1
            } else {
                timer.invalidate()
                isCountdownActive = false
                triggerCapture()
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
