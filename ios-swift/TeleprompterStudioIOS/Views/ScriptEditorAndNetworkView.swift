import SwiftUI

struct ScriptEditorAndNetworkView: View {
    @EnvironmentObject var engine: BroadcastEngine

    @State private var blocoInput: String = ""
    @State private var camInput: String = ""
    @State private var retrancaInput: String = ""
    @State private var scriptInput: String = ""

    private let quickCues = [
        "[CORTA CÂMERA 1]",
        "[CORTA CÂMERA 2]",
        "[CORTA CÂMERA 3]",
        "[CORTA GC - ]",
        "[ENTRA VT]",
        "[CHAMA VIVO]"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // 1. Editor da Lauda em Tempo Real
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("EDITOR DE LAUDA EM TEMPO REAL")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(Color(white: 0.6))
                        Spacer()
                        Text("AUTO-SAVE ATIVO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(red: 0.19, green: 0.82, blue: 0.35))
                    }

                    HStack(spacing: 8) {
                        TextField("BLOCO 01", text: $blocoInput)
                            .textInputAutocapitalization(.characters)
                            .modifier(StudioTextFieldModifier())
                            .onChange(of: blocoInput) { _ in commitChanges() }

                        TextField("CAM 1", text: $camInput)
                            .textInputAutocapitalization(.characters)
                            .modifier(StudioTextFieldModifier())
                            .onChange(of: camInput) { _ in commitChanges() }
                    }

                    TextField("RETRANCA / TÍTULO DA MATÉRIA", text: $retrancaInput)
                        .textInputAutocapitalization(.characters)
                        .modifier(StudioTextFieldModifier())
                        .onChange(of: retrancaInput) { _ in commitChanges() }

                    // Chips Rápidos de Rubrica Técnica
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(quickCues, id: \.self) { cue in
                                Button {
                                    scriptInput += "\n\(cue)\n"
                                    commitChanges()
                                } label: {
                                    Text("+ \(cue.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: ""))")
                                        .font(.system(size: 11, weight: .heavy))
                                        .foregroundColor(Color(red: 0.98, green: 0.75, blue: 0.14))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.18))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.45), lineWidth: 1)
                                        )
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }

                    TextEditor(text: $scriptInput)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(minHeight: 220)
                        .padding(8)
                        .background(Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .cornerRadius(12)
                        .onChange(of: scriptInput) { _ in commitChanges() }
                }
                .modifier(CockpitCardModifier())

                // 2. Servidor Nativo Embutido no iPhone (Ex: 172.16.1.73:3000)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("SERVIDOR NATIVO NO IPHONE (COMPANION / STREAM DECK / VMIX)")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(Color(white: 0.6))
                        Spacer()
                        Circle()
                            .fill(engine.isEmbeddedServerRunning ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                    }

                    Text("Este iPhone possui um servidor HTTP REST integrado na porta 3000. Você pode disparar Play/Pause, Velocidade e Flip direto do Bitfocus Companion, Stream Deck ou vMix apontando para o IP deste iPhone:")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.72))

                    HStack {
                        Text("http://\(engine.deviceWiFiIP):3000/api/status")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.29, green: 0.87, blue: 0.5))
                        Spacer()
                        Button {
                            UIPasteboard.general.string = "http://\(engine.deviceWiFiIP):3000"
                        } label: {
                            Text("Copiar IP")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                }
                .modifier(CockpitCardModifier())

                // 3. Sincronização Cliente WebSocket com o Servidor PC do Estúdio
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("CONECTAR AO SERVIDOR DO ESTÚDIO (PC 60HZ)")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(Color(white: 0.6))
                        Spacer()
                        Text(engine.isWsConnectedToStudio ? "ONLINE (\(engine.wsPingMs) ms)" : "AUTÔNOMO / OFFLINE")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundColor(engine.isWsConnectedToStudio ? .green : .orange)
                    }

                    HStack(spacing: 8) {
                        TextField("IP do PC do Estúdio (ex: 172.16.1.10:3000)", text: $engine.studioServerHost)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .modifier(StudioTextFieldModifier())

                        Button {
                            if engine.isWsConnectedToStudio {
                                engine.disconnectFromStudioServer()
                            } else {
                                engine.connectToStudioServer()
                            }
                        } label: {
                            Text(engine.isWsConnectedToStudio ? "Desconectar" : "Conectar")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .background(
                                    engine.isWsConnectedToStudio
                                        ? Color.red.opacity(0.8)
                                        : Color(red: 0.04, green: 0.52, blue: 1.0)
                                )
                                .cornerRadius(10)
                        }
                    }
                }
                .modifier(CockpitCardModifier())
            }
            .padding(12)
        }
        .background(Color(red: 0.03, green: 0.04, blue: 0.07))
        .onAppear {
            loadFromActiveStory()
        }
        .onChange(of: engine.state.storyId) { _ in
            loadFromActiveStory()
        }
    }

    private func loadFromActiveStory() {
        let story = engine.activeStory
        blocoInput = story.bloco
        camInput = story.cam
        retrancaInput = story.retranca
        scriptInput = story.text
    }

    private func commitChanges() {
        engine.updateActiveStory(
            bloco: blocoInput,
            cam: camInput,
            retranca: retrancaInput,
            text: scriptInput
        )
    }
}

struct StudioTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(10)
            .background(Color.black.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .cornerRadius(10)
    }
}

