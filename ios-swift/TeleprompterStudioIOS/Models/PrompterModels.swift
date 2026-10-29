import Foundation
import SwiftUI

// MARK: - Modelo de Lauda / Matéria da Escaleta (Rundown)
struct StoryItem: Identifiable, Codable, Equatable {
    var id: String
    var retranca: String
    var bloco: String
    var cam: String
    var text: String

    var cleanWordCount: Int {
        let withoutCues = text.replacingOccurrences(
            of: "\\[[^\\]]*\\]",
            with: "",
            options: .regularExpression
        )
        return withoutCues
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }

    func estimatedSeconds(atSpeed speed: Double) -> Int {
        let wpm = max(60.0, speed * 95.0)
        guard speed > 0.05 else { return 0 }
        return Int((Double(cleanWordCount) / wpm) * 60.0)
    }
}

// MARK: - Estado Centralizado do Teleprompter (Sincronizado a 60/120Hz)
struct PrompterState: Codable, Equatable {
    var storyId: String
    var scrollY: Double
    var speed: Double
    var isPaused: Bool
    var flipH: Bool
    var flipV: Bool
    var fontFamily: String
    var fontSizePx: Double
    var marginPercent: Double
    var cueLinePercent: Double
    var alphaMode: Bool
    var text: String

    static func defaultState(firstStory: StoryItem) -> PrompterState {
        PrompterState(
            storyId: firstStory.id,
            scrollY: 0.0,
            speed: 1.5,
            isPaused: true,
            flipH: false,
            flipV: false,
            fontFamily: "SF Pro Display",
            fontSizePx: 44.0,
            marginPercent: 8.0,
            cueLinePercent: 26.0,
            alphaMode: false,
            text: firstStory.text
        )
    }
}

// MARK: - Perfis Ópticos de Hardware: Do iPhone 12 até o iPhone 17 Pro Max
enum IPhoneHardwareProfile: String, CaseIterable, Identifiable, Codable {
    case auto = "auto"
    case iphone12_13Mini = "iphone-12-13-mini"
    case iphone12_13_14 = "iphone-12-13-14"
    case iphone12_13ProMax_14Plus = "iphone-12-13-promax"
    case iphone14Pro_15_16 = "iphone-14p-15-16"
    case iphone14_15ProMax_16Plus = "iphone-14pm-15pm-16plus"
    case iphone16Pro_17_17Pro = "iphone-16p-17-17p"
    case iphone16ProMax_17ProMax = "iphone-16pm-17pm"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto:
            return "Detecção Automática (iOS)"
        case .iphone12_13Mini:
            return "iPhone 12 Mini / 13 Mini (5.4\" • Notch)"
        case .iphone12_13_14:
            return "iPhone 12 / 12 Pro / 13 / 13 Pro / 14 (6.1\")"
        case .iphone12_13ProMax_14Plus:
            return "iPhone 12 Pro Max / 13 Pro Max / 14 Plus (6.7\")"
        case .iphone14Pro_15_16:
            return "iPhone 14 Pro / 15 / 15 Pro / 16 (Dynamic Island 6.1\")"
        case .iphone14_15ProMax_16Plus:
            return "iPhone 14/15 Pro Max / 15/16 Plus (Dynamic Island 6.7\")"
        case .iphone16Pro_17_17Pro:
            return "iPhone 16 Pro / 17 / 17 Air / 17 Pro (6.3\" • 120Hz)"
        case .iphone16ProMax_17ProMax:
            return "iPhone 16 Pro Max / 17 Pro Max (6.9\" • 120Hz ProMotion)"
        }
    }

    var recommendedFontSize: Double {
        switch self {
        case .auto: return 44.0
        case .iphone12_13Mini: return 34.0
        case .iphone12_13_14: return 40.0
        case .iphone12_13ProMax_14Plus: return 44.0
        case .iphone14Pro_15_16: return 42.0
        case .iphone14_15ProMax_16Plus: return 46.0
        case .iphone16Pro_17_17Pro: return 44.0
        case .iphone16ProMax_17ProMax: return 48.0
        }
    }

    var recommendedMarginPercent: Double {
        switch self {
        case .auto: return 8.0
        case .iphone12_13Mini: return 6.0
        case .iphone12_13_14: return 7.0
        case .iphone12_13ProMax_14Plus: return 8.0
        case .iphone14Pro_15_16: return 8.0
        case .iphone14_15ProMax_16Plus: return 9.0
        case .iphone16Pro_17_17Pro: return 8.0
        case .iphone16ProMax_17ProMax: return 10.0
        }
    }

    /// Altura ideal da agulha (Eye-Line) próxima à câmera TrueDepth (Notch / Dynamic Island)
    var recommendedCueLinePercent: Double {
        switch self {
        case .auto: return 25.0
        case .iphone12_13Mini: return 25.0
        case .iphone12_13_14: return 26.0
        case .iphone12_13ProMax_14Plus: return 26.0
        case .iphone14Pro_15_16: return 24.0
        case .iphone14_15ProMax_16Plus: return 24.0
        case .iphone16Pro_17_17Pro: return 23.0
        case .iphone16ProMax_17ProMax: return 23.0
        }
    }

    static func detectCurrentDevice() -> IPhoneHardwareProfile {
        let screen = UIScreen.main.bounds
        let minDim = min(screen.width, screen.height)
        let maxDim = max(screen.width, screen.height)

        if minDim >= 440 || maxDim >= 950 {
            return .iphone16ProMax_17ProMax
        } else if minDim == 402 || (maxDim >= 870 && maxDim < 900) {
            return .iphone16Pro_17_17Pro
        } else if minDim == 430 && maxDim == 932 {
            return .iphone14_15ProMax_16Plus
        } else if minDim == 393 && maxDim == 852 {
            return .iphone14Pro_15_16
        } else if minDim == 428 && maxDim == 926 {
            return .iphone12_13ProMax_14Plus
        } else if minDim == 390 && maxDim == 844 {
            return .iphone12_13_14
        } else if minDim <= 375 {
            return .iphone12_13Mini
        }
        return .iphone16ProMax_17ProMax
    }
}

// MARK: - Segmentos de Texto Formatado para Rubricas de Broadcast [CORTA CÂMERA 1]
struct BroadcastTextSegment: Identifiable {
    enum SegmentKind {
        case normalText(String)
        case cameraCue(String)
        case gcCue(String)
        case generalCue(String)
    }

    let id = UUID()
    let kind: SegmentKind
}

enum BroadcastScriptFormatter {
    static func parse(_ rawText: String) -> [BroadcastTextSegment] {
        let upperText = rawText.uppercased()
        guard let regex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]", options: []) else {
            return [BroadcastTextSegment(kind: .normalText(upperText))]
        }

        let nsString = upperText as NSString
        let matches = regex.matches(in: upperText, options: [], range: NSRange(location: 0, length: nsString.length))

        var segments: [BroadcastTextSegment] = []
        var lastLocation = 0

        for match in matches {
            let matchRange = match.range
            if matchRange.location > lastLocation {
                let textRange = NSRange(location: lastLocation, length: matchRange.location - lastLocation)
                let plain = nsString.substring(with: textRange)
                if !plain.isEmpty {
                    segments.append(BroadcastTextSegment(kind: .normalText(plain)))
                }
            }

            let innerRange = match.range(at: 1)
            let inner = nsString.substring(with: innerRange)
            let fullTag = "[\(inner)]"

            if inner.contains("CÂMERA") || inner.contains("CAMERA") || inner.contains("CAM") {
                segments.append(BroadcastTextSegment(kind: .cameraCue(fullTag)))
            } else if inner.contains("GC") || inner.contains("ARTE") || inner.contains("MAPA") {
                segments.append(BroadcastTextSegment(kind: .gcCue(fullTag)))
            } else {
                segments.append(BroadcastTextSegment(kind: .generalCue(fullTag)))
            }

            lastLocation = matchRange.location + matchRange.length
        }

        if lastLocation < nsString.length {
            let tail = nsString.substring(from: lastLocation)
            if !tail.isEmpty {
                segments.append(BroadcastTextSegment(kind: .normalText(tail)))
            }
        }

        return segments
    }
}

// MARK: - Escaleta Padrão de Telejornalismo
enum DefaultRundownFactory {
    static let stories: [StoryItem] = [
        StoryItem(
            id: "bloco-01-materia-01",
            retranca: "ABERTURA / ESCALADA",
            bloco: "BLOCO 01",
            cam: "CAM 1",
            text: "[BOA NOITE]\n\nBEM-VINDOS AO JORNAL DA REDE.\n\n[CORTA CÂMERA 1]\n\nHOJE VAMOS ACOMPANHAR AS PRINCIPAIS NOTÍCIAS DO DIA E OS DESDOBRAMENTOS POLÍTICOS E ECONÔMICOS NO PAÍS.\n\n[CORTA GC - MANCHETE PRINCIPAL]\n\nMAIS DETALHES EM INSTANTES APÓS O INTERVALO COMERCIAL."
        ),
        StoryItem(
            id: "bloco-01-materia-02",
            retranca: "ECONOMIA - TAXA DE JUROS",
            bloco: "BLOCO 01",
            cam: "CAM 2",
            text: "[CORTA CÂMERA 2]\n\nO COMITÊ DE POLÍTICA MONETÁRIA DIVULGOU HÁ POUCO A NOVA DECISÃO SOBRE A TAXA BÁSICA DE JUROS.\n\n[ENTRA ARTE TELA CHEIA - SELIC]\n\nSEGUNDO OS ANALISTAS DO MERCADO FINANCEIRO, O CENÁRIO DE INFLAÇÃO SEGUE CONTROLADO, MAS EXIGE CAUTELA NOS PRÓXIMOS TRIMESTRES.\n\n[CHAMA VIVO - BRASÍLIA]\n\nVAMOS AO VIVO PARA BRASÍLIA COM MAIS INFORMAÇÕES DIRETO DO MINISTÉRIO DA FAZENDA."
        ),
        StoryItem(
            id: "bloco-01-materia-03",
            retranca: "PREVISÃO DO TEMPO",
            bloco: "BLOCO 01",
            cam: "CAM 3",
            text: "[CORTA CÂMERA 3 - TELÃO]\n\nUMA FRENTE FRIA AVANÇA PELO SUL E SUDESTE DO PAÍS NESTA QUARTA-FEIRA, TRAZENDO CHUVAS INTENSAS E QUEDA NAS TEMPERATURAS.\n\n[ENTRA MAPA SATÉLITE]\n\nNAS CAPITAIS DO NORDESTE E CENTRO-OESTE, O SOL PREDOMINA E OS ÍNDICES DE UMIDADE RELATIVA DO AR CONTINUAM EM ALERTA."
        ),
        StoryItem(
            id: "bloco-02-materia-01",
            retranca: "ENCERRAMENTO",
            bloco: "BLOCO 02",
            cam: "CAM 1",
            text: "[CORTA CÂMERA 1 - PLANO GERAL]\n\nO JORNAL DA REDE FICA POR AQUI.\n\nTODAS AS REPORTAGENS DESTA EDIÇÃO JÁ ESTÃO DISPONÍVEIS NO NOSSO PORTAL E NAS REDES SOCIAIS.\n\n[SOBE CRÉDITOS / TRILHA FINAL]\n\nUMA EXCELENTE NOITE A TODOS E ATÉ AMANHÃ."
        )
    ]
}

