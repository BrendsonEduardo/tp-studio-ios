import SwiftUI

struct PrompterStageView: View {
    @EnvironmentObject var engine: BroadcastEngine

    @State private var dragStartScrollY: Double? = nil
    @State private var pinchStartFontSize: Double? = nil

    var body: some View {
        GeometryReader { geo in
            let cueY = geo.size.height * CGFloat(engine.state.cueLinePercent / 100.0)
            let horizontalPadding = geo.size.width * CGFloat(engine.state.marginPercent / 100.0)

            ZStack(alignment: .topLeading) {
                // Fundo OLED Preto Puro (ou Câmera Frontal Eye-Contact se ativada)
                Color.black.ignoresSafeArea()

                if engine.isFrontCameraActive {
                    FrontCameraPreviewView()
                        .ignoresSafeArea()
                        .opacity(0.32)
                }

                // Palco Óptico com suporte a Espelho Beam Splitter (Flip H / Flip V)
                ZStack(alignment: .topLeading) {
                    BroadcastFormattedScriptView(
                        rawText: engine.state.text,
                        fontSize: CGFloat(engine.state.fontSizePx)
                    )
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, cueY)
                    .padding(.bottom, geo.size.height * 0.75)
                    .frame(width: geo.size.width, alignment: .leading)
                    .offset(y: -CGFloat(engine.renderedScrollY))
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .scaleEffect(
                    x: engine.state.flipH ? -1.0 : 1.0,
                    y: engine.state.flipV ? -1.0 : 1.0,
                    anchor: .center
                )
                .clipped()

                // Agulha / Eye-Line Calibrada (Triângulos Vermelhos + Linha Guia)
                CueLineOverlayView(cueY: cueY, width: geo.size.width)

                // Botão discreto para sair do Modo Imersivo
                if engine.isImmersiveMode {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    engine.isImmersiveMode = false
                                }
                            } label: {
                                Text("✕ Mostrar Menu (2 Toques)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(white: 0.85))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.65))
                                    .overlay(
                                        Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1)
                                    )
                                    .clipShape(Capsule())
                            }
                            .padding(.top, 8)
                            .padding(.trailing, 14)
                        }
                        Spacer()
                    }
                }

                // Barra Flutuante de Controles Rápidos (Oculta em Modo Imersivo)
                if !engine.isImmersiveMode {
                    VStack {
                        Spacer()
                        PrompterFloatingDockView()
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
            // Toque duplo: alterna Modo Imersivo 100% Limpo OLED
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    engine.isImmersiveMode.toggle()
                }
            }
            // Toque simples: Play / Pause imediato
            .onTapGesture(count: 1) {
                engine.togglePlayPause()
            }
            // Arrastar vertical (Touch Scrub / Jog manual a 60/120Hz)
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        if dragStartScrollY == nil {
                            dragStartScrollY = engine.state.scrollY
                        }
                        let flipMultiplier = engine.state.flipV ? -1.0 : 1.0
                        let deltaY = Double(-value.translation.height) * 1.15 * flipMultiplier
                        if let startY = dragStartScrollY {
                            engine.scrubTo(scrollY: startY + deltaY)
                        }
                    }
                    .onEnded { _ in
                        dragStartScrollY = nil
                    }
            )
            // Pinça com 2 dedos (Pinch-to-Zoom para tamanho da fonte)
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { scale in
                        if pinchStartFontSize == nil {
                            pinchStartFontSize = engine.state.fontSizePx
                        }
                        if let baseFont = pinchStartFontSize {
                            let newFont = (baseFont * Double(scale)).rounded()
                            engine.updateVisualGeometry(fontSize: newFont)
                        }
                    }
                    .onEnded { _ in
                        pinchStartFontSize = nil
                    }
            )
        }
    }
}

// MARK: - Marcador de Linha de Leitura (Agulha / Eye-Line)
struct CueLineOverlayView: View {
    let cueY: CGFloat
    let width: CGFloat

    var body: some View {
        ZStack {
            // Linha Guia Horizontal
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.65),
                            Color.red.opacity(0.12),
                            Color.red.opacity(0.12),
                            Color.red.opacity(0.65)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: 2)
                .position(x: width / 2.0, y: cueY)

            // Indicador Esquerdo
            CueTriangleShape(pointingRight: true)
                .fill(Color(red: 1.0, green: 0.22, blue: 0.2))
                .frame(width: 18, height: 22)
                .shadow(color: .red.opacity(0.7), radius: 5)
                .position(x: 14, y: cueY)

            // Indicador Direito
            CueTriangleShape(pointingRight: false)
                .fill(Color(red: 1.0, green: 0.22, blue: 0.2))
                .frame(width: 18, height: 22)
                .shadow(color: .red.opacity(0.7), radius: 5)
                .position(x: width - 14, y: cueY)
        }
        .allowsHitTesting(false)
    }
}

struct CueTriangleShape: Shape {
    let pointingRight: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointingRight {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Renderizador de Texto com Destaques de Rubricas [CORTA CÂMERA 1] / [GC]
struct BroadcastFormattedScriptView: View {
    let rawText: String
    let fontSize: CGFloat

    var body: some View {
        let segments = BroadcastScriptFormatter.parse(rawText)
        VStack(alignment: .leading, spacing: fontSize * 0.22) {
            ForEach(segments) { segment in
                switch segment.kind {
                case .normalText(let str):
                    Text(str)
                        .font(.system(size: fontSize, weight: .heavy, design: .default))
                        .foregroundColor(.white)
                        .lineSpacing(fontSize * 0.18)
                        .fixedSize(horizontal: false, vertical: true)

                case .cameraCue(let tag):
                    Text(tag)
                        .font(.system(size: max(18, fontSize * 0.78), weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.94, green: 0.27, blue: 0.27))
                        .cornerRadius(8)

                case .gcCue(let tag):
                    Text(tag)
                        .font(.system(size: max(18, fontSize * 0.78), weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.22, green: 0.74, blue: 0.97))
                        .cornerRadius(8)

                case .generalCue(let tag):
                    Text(tag)
                        .font(.system(size: max(18, fontSize * 0.78), weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.96, green: 0.62, blue: 0.04))
                        .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - Dock Flutuante Glassmorphism na Aba Prompter
struct PrompterFloatingDockView: View {
    @EnvironmentObject var engine: BroadcastEngine

    var body: some View {
        HStack(spacing: 8) {
            DockButton(label: "⏮") {
                engine.jumpToTop()
            }

            DockButton(label: "⏪") {
                engine.jumpToPreviousStory()
            }

            Button {
                engine.togglePlayPause()
            } label: {
                Text(engine.state.isPaused ? "▶ PLAY" : "⏸ PAUSAR")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(engine.state.isPaused ? Color.black : Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(
                        engine.state.isPaused
                            ? Color(red: 0.19, green: 0.82, blue: 0.35)
                            : Color(red: 1.0, green: 0.27, blue: 0.23)
                    )
                    .cornerRadius(10)
            }

            DockButton(label: "⏩") {
                engine.jumpToNextStory()
            }

            DockButton(label: "−") {
                engine.adjustSpeed(delta: -0.2)
            }

            Text(String(format: "%.1fx", engine.state.speed))
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundColor(Color(red: 0.22, green: 0.74, blue: 0.97))
                .frame(minWidth: 38)

            DockButton(label: "+") {
                engine.adjustSpeed(delta: 0.2)
            }

            DockButton(label: "↔", isActive: engine.state.flipH) {
                engine.toggleFlipHorizontal()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.88))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(16)
    }
}

struct DockButton: View {
    let label: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isActive ? Color(red: 0.22, green: 0.74, blue: 0.97) : .white)
                .frame(width: 36, height: 38)
                .background(
                    isActive
                        ? Color(red: 0.22, green: 0.74, blue: 0.97).opacity(0.25)
                        : Color.white.opacity(0.1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isActive ? Color(red: 0.22, green: 0.74, blue: 0.97) : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                )
                .cornerRadius(10)
        }
    }
}

