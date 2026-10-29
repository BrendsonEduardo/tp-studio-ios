import SwiftUI

struct CockpitControlView: View {
    @EnvironmentObject var engine: BroadcastEngine
    @State private var jogStartScrollY: Double? = nil

    private let speedPresets: [Double] = [0.8, 1.2, 1.5, 2.0, 3.0]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // 1. Telemetria em Tempo Real
                HStack(spacing: 8) {
                    TelemetryMetricBox(
                        title: "VELOCIDADE",
                        value: String(format: "%.1fx", engine.state.speed)
                    )
                    TelemetryMetricBox(
                        title: "RITMO",
                        value: "\(engine.currentWPM) WPM"
                    )
                    TelemetryMetricBox(
                        title: "RESTANTE",
                        value: engine.remainingTimeFormatted
                    )
                    TelemetryMetricBox(
                        title: "POSIÇÃO Y",
                        value: "\(Int(engine.state.scrollY)) px"
                    )
                }

                // 2. Transporte Master & Jog/Shuttle Touch Pad
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("TRANSPORTE MASTER & JOG TOUCH")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(Color(white: 0.6))
                        Spacer()
                        Text("\(engine.activeStory.bloco) • \(engine.activeStory.cam)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.22, green: 0.74, blue: 0.97))
                    }

                    Button {
                        engine.togglePlayPause()
                    } label: {
                        Text(engine.state.isPaused ? "▶ INICIAR LEITURA (NO AR)" : "⏸ PAUSAR TELEPROMPTER (NO AR)")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(engine.state.isPaused ? Color(red: 0.29, green: 0.87, blue: 0.5) : Color(red: 0.99, green: 0.65, blue: 0.65))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                engine.state.isPaused
                                    ? Color(red: 0.13, green: 0.77, blue: 0.37).opacity(0.18)
                                    : Color(red: 0.94, green: 0.27, blue: 0.27).opacity(0.25)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        engine.state.isPaused
                                            ? Color(red: 0.13, green: 0.77, blue: 0.37)
                                            : Color(red: 0.94, green: 0.27, blue: 0.27),
                                        lineWidth: 2
                                    )
                            )
                            .cornerRadius(12)
                    }

                    HStack(spacing: 8) {
                        CockpitSecondaryButton(title: "⏮ Topo") {
                            engine.jumpToTop()
                        }
                        CockpitSecondaryButton(title: "⏪ Anterior") {
                            engine.jumpToPreviousStory()
                        }
                        CockpitSecondaryButton(title: "Próxima ⏩") {
                            engine.jumpToNextStory()
                        }
                    }

                    // Trilha Tátil de Jog / Shuttle
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.05, green: 0.09, blue: 0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0.22, green: 0.74, blue: 0.97).opacity(0.45), lineWidth: 1)
                            )

                        Text("⇆ DESLIZE O DEDO AQUI PARA JOG / SHUTTLE MANUAL")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.73, green: 0.9, blue: 0.99))
                    }
                    .frame(height: 52)
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                if jogStartScrollY == nil {
                                    jogStartScrollY = engine.state.scrollY
                                }
                                if let base = jogStartScrollY {
                                    let delta = Double(value.translation.width) * 2.2
                                    engine.scrubTo(scrollY: base + delta)
                                }
                            }
                            .onEnded { _ in
                                jogStartScrollY = nil
                            }
                    )
                }
                .modifier(CockpitCardModifier())

                // 3. Mini Monitor de Retorno Ao Vivo
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("MONITOR DE RETORNO AO VIVO")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(Color(white: 0.6))
                        Spacer()
                        Text("ÓPTICA: \(engine.state.flipH ? "FLIP-H " : "")\(engine.state.flipV ? "FLIP-V" : (!engine.state.flipH ? "NORMAL" : ""))")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(white: 0.7))
                    }

                    ZStack(alignment: .topLeading) {
                        Color.black

                        Text(engine.state.text.uppercased())
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.top, 42)
                            .offset(y: -CGFloat(engine.renderedScrollY * 0.34))

                        Rectangle()
                            .fill(Color.red.opacity(0.75))
                            .frame(height: 1.5)
                            .offset(y: 42)
                    }
                    .frame(height: 115)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 0.22, green: 0.74, blue: 0.97).opacity(0.35), lineWidth: 1)
                    )
                }
                .modifier(CockpitCardModifier())

                // 4. Controle de Velocidade & Presets
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("VELOCIDADE DE LEITURA")
                            .font(.system(size: 12, weight: .bold))
                        Spacer()
                        Text(String(format: "%.1fx", engine.state.speed))
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(red: 0.22, green: 0.74, blue: 0.97))
                    }

                    Slider(
                        value: Binding(
                            get: { engine.state.speed },
                            set: { engine.setSpeed($0) }
                        ),
                        in: 0.0...8.0,
                        step: 0.1
                    )
                    .accentColor(Color(red: 0.04, green: 0.52, blue: 1.0))

                    HStack(spacing: 6) {
                        ForEach(speedPresets, id: \.self) { preset in
                            CockpitSecondaryButton(
                                title: String(format: "%.1fx", preset),
                                isActive: abs(engine.state.speed - preset) < 0.05
                            ) {
                                engine.setSpeed(preset)
                            }
                        }
                    }
                }
                .modifier(CockpitCardModifier())

                // 5. Calibração Óptica para iPhone 12 até iPhone 17 Pro Max
                VStack(alignment: .leading, spacing: 12) {
                    Text("CALIBRAÇÃO IPHONE (12 ATÉ 17 PRO MAX) & ÓPTICA")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(Color(white: 0.6))

                    Picker("Modelo do iPhone", selection: Binding(
                        get: { engine.hardwareProfile },
                        set: { engine.applyHardwareProfile($0) }
                    )) {
                        ForEach(IPhoneHardwareProfile.allCases) { profile in
                            Text(profile.displayName).tag(profile)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.45))
                    .cornerRadius(10)

                    HStack(spacing: 8) {
                        CockpitSecondaryButton(
                            title: "↔ Flip Horizontal",
                            isActive: engine.state.flipH
                        ) {
                            engine.toggleFlipHorizontal()
                        }

                        CockpitSecondaryButton(
                            title: "↕ Flip Vertical",
                            isActive: engine.state.flipV
                        ) {
                            engine.toggleFlipVertical()
                        }
                    }

                    // Tamanho da Fonte
                    VStack(spacing: 4) {
                        HStack {
                            Text("Tamanho da Fonte")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text("\(Int(engine.state.fontSizePx)) px")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        Slider(
                            value: Binding(
                                get: { engine.state.fontSizePx },
                                set: { engine.updateVisualGeometry(fontSize: $0) }
                            ),
                            in: 22...110,
                            step: 2
                        )
                    }

                    // Margens Laterais
                    VStack(spacing: 4) {
                        HStack {
                            Text("Margens Laterais")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text("\(Int(engine.state.marginPercent))%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        Slider(
                            value: Binding(
                                get: { engine.state.marginPercent },
                                set: { engine.updateVisualGeometry(margin: $0) }
                            ),
                            in: 2...30,
                            step: 1
                        )
                    }

                    // Linha de Leitura (Agulha / Eye-Line TrueDepth)
                    VStack(spacing: 4) {
                        HStack {
                            Text("Altura da Agulha (Eye-Line / Lente)")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text("\(Int(engine.state.cueLinePercent))%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        Slider(
                            value: Binding(
                                get: { engine.state.cueLinePercent },
                                set: { engine.updateVisualGeometry(cueLine: $0) }
                            ),
                            in: 12...65,
                            step: 1
                        )
                    }
                }
                .modifier(CockpitCardModifier())
            }
            .padding(12)
        }
        .background(Color(red: 0.03, green: 0.04, blue: 0.07))
    }
}

struct TelemetryMetricBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color(white: 0.6))
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundColor(Color(red: 0.22, green: 0.74, blue: 0.97))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(red: 0.05, green: 0.07, blue: 0.13))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .cornerRadius(10)
    }
}

struct CockpitSecondaryButton: View {
    let title: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isActive ? Color(red: 0.44, green: 0.72, blue: 1.0) : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isActive
                        ? Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.28)
                        : Color.white.opacity(0.08)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isActive ? Color(red: 0.04, green: 0.52, blue: 1.0) : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                )
                .cornerRadius(10)
        }
    }
}

struct CockpitCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(Color(red: 0.08, green: 0.11, blue: 0.18).opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .cornerRadius(14)
    }
}

