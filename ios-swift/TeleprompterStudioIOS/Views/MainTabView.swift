import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var engine: BroadcastEngine
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Top Broadcast Tally Bar (Oculta em Modo Imersivo 100% Limpo OLED)
            if !engine.isImmersiveMode {
                TopBroadcastBarView(selectedTab: $selectedTab)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Conteúdo Principal da Aba Selecionada
            ZStack {
                switch selectedTab {
                case 0:
                    PrompterStageView()
                case 1:
                    CockpitControlView()
                case 2:
                    RundownListView(selectedTab: $selectedTab)
                default:
                    ScriptEditorAndNetworkView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Barra de Abas Inferior Nativa (Oculta em Modo Imersivo)
            if !engine.isImmersiveMode {
                BottomBroadcastTabBar(selectedTab: $selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .statusBar(hidden: engine.isImmersiveMode)
    }
}

// MARK: - Top Broadcast Tally Bar (Safe Area p/ Notch e Dynamic Island)
struct TopBroadcastBarView: View {
    @EnvironmentObject var engine: BroadcastEngine
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 10) {
            // Botão Tally (ON AIR / STANDBY)
            Button {
                engine.togglePlayPause()
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(engine.state.isPaused ? Color.orange : Color.white)
                        .frame(width: 7, height: 7)
                    Text(engine.state.isPaused ? "PAUSA" : "NO AR")
                        .font(.system(size: 11, weight: .black))
                }
                .foregroundColor(engine.state.isPaused ? Color.orange : Color.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    engine.state.isPaused
                        ? Color.orange.opacity(0.16)
                        : Color.red.opacity(0.85)
                )
                .overlay(
                    Capsule()
                        .stroke(engine.state.isPaused ? Color.orange : Color.red, lineWidth: 1)
                )
                .clipShape(Capsule())
            }

            Spacer(minLength: 4)

            // Título da Matéria Ativa e Status do Aparelho / Rede
            VStack(spacing: 2) {
                Text("\(engine.activeStory.bloco) • \(engine.activeStory.retranca)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Circle()
                        .fill(engine.isWsConnectedToStudio ? Color.green : Color(red: 0.22, green: 0.74, blue: 0.97))
                        .frame(width: 6, height: 6)
                    Text(engine.isWsConnectedToStudio ? "ESTÚDIO 60HZ" : "IP \(engine.deviceWiFiIP):3000")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(white: 0.65))
                }
            }

            Spacer(minLength: 4)

            // Ações Rápidas: Câmera Frontal Eye-Contact & Tela Cheia Imersiva
            HStack(spacing: 6) {
                Button {
                    engine.isFrontCameraActive.toggle()
                    selectedTab = 0
                } label: {
                    Text("📷")
                        .font(.system(size: 13))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            engine.isFrontCameraActive
                                ? Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.35)
                                : Color.white.opacity(0.08)
                        )
                        .cornerRadius(8)
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = 0
                        engine.isImmersiveMode.toggle()
                    }
                } label: {
                    Text("⛶")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(red: 0.03, green: 0.05, blue: 0.09).opacity(0.95))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Barra de Abas Inferior Nativa
struct BottomBroadcastTabBar: View {
    @Binding var selectedTab: Int

    private let items: [(icon: String, title: String, tag: Int)] = [
        ("📺", "Prompter", 0),
        ("🎛", "Controle", 1),
        ("📋", "Escaleta", 2),
        ("✏️", "Editor & Rede", 3)
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tag) { item in
                let isSelected = (selectedTab == item.tag)
                Button {
                    selectedTab = item.tag
                } label: {
                    VStack(spacing: 3) {
                        Text(item.icon)
                            .font(.system(size: 18))
                        Text(item.title)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(
                                isSelected
                                    ? Color(red: 0.04, green: 0.52, blue: 1.0)
                                    : Color(white: 0.6)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
            }
        }
        .background(Color(red: 0.03, green: 0.05, blue: 0.09).opacity(0.96))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
    }
}

