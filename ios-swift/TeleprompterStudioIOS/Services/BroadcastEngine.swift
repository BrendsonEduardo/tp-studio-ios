import Combine
import Foundation
import GameController
import Network
import QuartzCore
import UIKit

final class BroadcastEngine: ObservableObject {
    // MARK: - Estado Publicado para a Interface SwiftUI
    @Published var stories: [StoryItem]
    @Published var state: PrompterState
    @Published var renderedScrollY: Double = 0.0
    @Published var hardwareProfile: IPhoneHardwareProfile = .auto
    @Published var detectedProfile: IPhoneHardwareProfile = .detectCurrentDevice()
    @Published var isStudioFrame1to1: Bool = false
    @Published var isImmersiveMode: Bool = false
    @Published var isFrontCameraActive: Bool = false

    // Telemetria & Rede (Suporta iPhone como Servidor 172.16.1.73:3000 E Cliente WS)
    @Published var deviceWiFiIP: String = "172.16.1.73"
    @Published var studioServerHost: String = ""
    @Published var isWsConnectedToStudio: Bool = false
    @Published var isEmbeddedServerRunning: Bool = false
    @Published var connectedEmbeddedClients: Int = 0
    @Published var wsPingMs: Int = 1
    @Published var connectedGamepadName: String? = nil

    // MARK: - Propriedades Internas de Motor 60/120Hz e Rede
    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var lastManualScrubDate: Date = .distantPast

    private var wsTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var pingTimer: Timer?

    private var nwListener: NWListener?

    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let selectionGenerator = UISelectionFeedbackGenerator()

    private let storiesStorageKey = "tp_swift_rundown_v1"
    private let stateStorageKey = "tp_swift_state_v1"
    private let studioHostStorageKey = "tp_swift_studio_host_v1"

    init() {
        let loadedStories: [StoryItem]
        if let data = UserDefaults.standard.data(forKey: storiesStorageKey),
           let decoded = try? JSONDecoder().decode([StoryItem].self, from: data),
           !decoded.isEmpty {
            loadedStories = decoded
        } else {
            loadedStories = DefaultRundownFactory.stories
        }
        self.stories = loadedStories

        if let stateData = UserDefaults.standard.data(forKey: stateStorageKey),
           var decodedState = try? JSONDecoder().decode(PrompterState.self, from: stateData) {
            decodedState.isPaused = true
            self.state = decodedState
        } else {
            self.state = PrompterState.defaultState(firstStory: loadedStories[0])
        }

        self.studioServerHost = UserDefaults.standard.string(forKey: studioHostStorageKey) ?? ""
        self.detectedProfile = IPhoneHardwareProfile.detectCurrentDevice()
        self.deviceWiFiIP = Self.readLocalWiFiIPAddress() ?? "172.16.1.73"

        // Mantém a tela do iPhone sempre acesa durante a operação do Teleprompter
        UIApplication.shared.isIdleTimerDisabled = true

        startDisplayLink60_120Hz()
        startEmbeddedBroadcastServer(port: 3000)
        setupGameControllerObservers()

        if !studioServerHost.isEmpty {
            connectToStudioServer()
        }
    }

    // MARK: - Motor Gráfico CADisplayLink (60Hz / 120Hz ProMotion LERP)
    private func startDisplayLink60_120Hz() {
        displayLink?.invalidate()
        let link = CADisplayLink(target: DisplayLinkProxy(engine: self), selector: #selector(DisplayLinkProxy.onFrame(_:)))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        } else {
            link.preferredFramesPerSecond = 60
        }
        link.add(to: .main, forMode: .common)
        self.displayLink = link
    }

    fileprivate func stepDisplayFrame(timestamp: CFTimeInterval) {
        if lastFrameTimestamp == 0 {
            lastFrameTimestamp = timestamp
        }
        let dt = min(0.05, max(0.004, timestamp - lastFrameTimestamp))
        lastFrameTimestamp = timestamp

        // Normaliza o avanço para 60 ticks/segundo (16.66ms) independente se a tela roda a 60Hz ou 120Hz ProMotion
        let tickScale = dt * 60.0
        let manualScrubRecent = Date().timeIntervalSince(lastManualScrubDate) < 0.08

        if !state.isPaused && !isWsConnectedToStudio && !manualScrubRecent {
            state.scrollY = max(0.0, state.scrollY + (state.speed * tickScale))
        }

        // Interpolação Linear (LERP) acelerada por GPU
        let diff = state.scrollY - renderedScrollY
        if abs(diff) > 180.0 || !state.isPaused {
            renderedScrollY += diff * 0.65
            if abs(state.scrollY - renderedScrollY) < 0.4 {
                renderedScrollY = state.scrollY
            }
        } else if abs(diff) > 0.05 {
            renderedScrollY += diff * 0.35
        } else {
            renderedScrollY = state.scrollY
        }
    }

    // MARK: - Comandos de Transporte, Velocidade e Calibração iPhone 12–17 Pro Max
    func togglePlayPause() {
        state.isPaused.toggle()
        impactGenerator.impactOccurred()
        saveLocalState()
        sendStudioUpdate(type: "UPDATE_STATE", payload: ["isPaused": state.isPaused])
    }

    func setSpeed(_ newSpeed: Double) {
        let clamped = max(0.0, min(15.0, (newSpeed * 10.0).rounded() / 10.0))
        state.speed = clamped
        selectionGenerator.selectionChanged()
        saveLocalState()
        sendStudioUpdate(type: "UPDATE_STATE", payload: ["speed": clamped])
    }

    func adjustSpeed(delta: Double) {
        setSpeed(state.speed + delta)
    }

    func scrubTo(scrollY: Double) {
        lastManualScrubDate = Date()
        let clamped = max(0.0, scrollY)
        state.scrollY = clamped
        sendStudioUpdate(type: "UPDATE_STATE", payload: ["scrollY": clamped])
    }

    func jumpToTop() {
        impactGenerator.impactOccurred()
        state.scrollY = 0.0
        renderedScrollY = 0.0
        saveLocalState()
        sendStudioUpdate(type: "UPDATE_STATE", payload: ["scrollY": 0.0])
    }

    func selectStory(id: String, resetScroll: Bool = true) {
        guard let found = stories.first(where: { $0.id == id }) else { return }
        selectionGenerator.selectionChanged()
        state.storyId = found.id
        state.text = found.text
        if resetScroll {
            state.scrollY = 0.0
            renderedScrollY = 0.0
        }
        saveLocalState()
        sendStudioUpdate(
            type: "UPDATE_CONFIG",
            payload: [
                "storyId": found.id,
                "text": found.text,
                "scrollY": state.scrollY
            ]
        )
    }

    func jumpToNextStory() {
        guard !stories.isEmpty else { return }
        let idx = stories.firstIndex(where: { $0.id == state.storyId }) ?? 0
        let nextIdx = (idx + 1) % stories.count
        selectStory(id: stories[nextIdx].id, resetScroll: true)
    }

    func jumpToPreviousStory() {
        guard !stories.isEmpty else { return }
        let idx = stories.firstIndex(where: { $0.id == state.storyId }) ?? 0
        let prevIdx = (idx - 1 + stories.count) % stories.count
        selectStory(id: stories[prevIdx].id, resetScroll: true)
    }

    func toggleFlipHorizontal() {
        state.flipH.toggle()
        selectionGenerator.selectionChanged()
        saveLocalState()
        sendStudioUpdate(type: "UPDATE_CONFIG", payload: ["flipH": state.flipH])
    }

    func toggleFlipVertical() {
        state.flipV.toggle()
        selectionGenerator.selectionChanged()
        saveLocalState()
        sendStudioUpdate(type: "UPDATE_CONFIG", payload: ["flipV": state.flipV])
    }

    func applyHardwareProfile(_ profile: IPhoneHardwareProfile) {
        hardwareProfile = profile
        let active = (profile == .auto) ? detectedProfile : profile
        state.fontSizePx = active.recommendedFontSize
        state.marginPercent = active.recommendedMarginPercent
        state.cueLinePercent = active.recommendedCueLinePercent
        selectionGenerator.selectionChanged()
        saveLocalState()
        sendStudioUpdate(
            type: "UPDATE_CONFIG",
            payload: [
                "fontSizePx": state.fontSizePx,
                "marginPercent": state.marginPercent,
                "cueLinePercent": state.cueLinePercent
            ]
        )
    }

    func updateVisualGeometry(fontSize: Double? = nil, margin: Double? = nil, cueLine: Double? = nil) {
        if let f = fontSize { state.fontSizePx = max(20.0, min(110.0, f)) }
        if let m = margin { state.marginPercent = max(2.0, min(30.0, m)) }
        if let c = cueLine { state.cueLinePercent = max(12.0, min(65.0, c)) }
        saveLocalState()
        sendStudioUpdate(
            type: "UPDATE_CONFIG",
            payload: [
                "fontSizePx": state.fontSizePx,
                "marginPercent": state.marginPercent,
                "cueLinePercent": state.cueLinePercent
            ]
        )
    }

    // MARK: - Gestão da Escaleta (Rundown) e Editor de Laudas
    var activeStory: StoryItem {
        stories.first(where: { $0.id == state.storyId }) ?? stories.first ?? DefaultRundownFactory.stories[0]
    }

    func addNewStory() -> StoryItem {
        let index = stories.count + 1
        let newStory = StoryItem(
            id: "materia-\(Int(Date().timeIntervalSince1970 * 1000))",
            retranca: "NOVA MATÉRIA #\(index)",
            bloco: String(format: "BLOCO %02d", index),
            cam: "CAM 1",
            text: "[CORTA CÂMERA 1]\n\nDIGITE O TEXTO DA NOVA MATÉRIA AQUI."
        )
        stories.append(newStory)
        selectStory(id: newStory.id, resetScroll: true)
        return newStory
    }

    func updateActiveStory(bloco: String, cam: String, retranca: String, text: String) {
        guard let idx = stories.firstIndex(where: { $0.id == state.storyId }) else { return }
        stories[idx].bloco = bloco.uppercased()
        stories[idx].cam = cam.uppercased()
        stories[idx].retranca = retranca.uppercased()
        stories[idx].text = text
        state.text = text
        saveLocalState()
        sendStudioUpdate(type: "UPDATE_CONFIG", payload: ["text": text])
    }

    func deleteStories(at offsets: IndexSet) {
        stories.remove(atOffsets: offsets)
        if stories.isEmpty {
            stories.append(
                StoryItem(
                    id: "materia-\(Int(Date().timeIntervalSince1970 * 1000))",
                    retranca: "NOVA LAUDA",
                    bloco: "BLOCO 01",
                    cam: "CAM 1",
                    text: "[CORTA CÂMERA 1]\n\nDIGITE O TEXTO DA LAUDA AQUI."
                )
            )
        }
        if !stories.contains(where: { $0.id == state.storyId }) {
            selectStory(id: stories[0].id, resetScroll: true)
        } else {
            saveLocalState()
        }
    }

    // MARK: - Métricas de Telejornalismo (WPM & Tempo Restante)
    var currentWPM: Int {
        Int(max(60.0, (state.speed * 95.0).rounded()))
    }

    var remainingTimeFormatted: String {
        let totalWords = Double(activeStory.cleanWordCount)
        let estimatedTotalScroll = max(300.0, totalWords * 4.2)
        let progress = min(1.0, max(0.0, state.scrollY / estimatedTotalScroll))
        let remainingWords = totalWords * (1.0 - progress)
        guard state.speed > 0.05 else { return "00:00" }
        let seconds = Int((remainingWords / Double(currentWPM)) * 60.0)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func saveLocalState() {
        if let encodedStories = try? JSONEncoder().encode(stories) {
            UserDefaults.standard.set(encodedStories, forKey: storiesStorageKey)
        }
        if let encodedState = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encodedState, forKey: stateStorageKey)
        }
        UserDefaults.standard.set(studioServerHost, forKey: studioHostStorageKey)
    }

    // MARK: - Conexão WebSocket Cliente (Conectar o iPhone ao Servidor do PC)
    func connectToStudioServer() {
        disconnectFromStudioServer()
        let trimmed = studioServerHost
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "ws://", with: "")
            .replacingOccurrences(of: "wss://", with: "")

        guard !trimmed.isEmpty else { return }
        let hostWithPort = trimmed.contains(":") ? trimmed : "\(trimmed):3000"
        guard let url = URL(string: "ws://\(hostWithPort)") else { return }

        saveLocalState()
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        self.urlSession = session
        self.wsTask = task
        task.resume()

        receiveNextWebSocketMessage()

        pingTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.sendPingCheck()
        }
    }

    func disconnectFromStudioServer() {
        pingTimer?.invalidate()
        pingTimer = nil
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        isWsConnectedToStudio = false
    }

    private func receiveNextWebSocketMessage() {
        wsTask?.receive { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let message):
                    self.isWsConnectedToStudio = true
                    if case .string(let text) = message {
                        self.handleIncomingServerJSON(text)
                    }
                    self.receiveNextWebSocketMessage()
                case .failure:
                    self.isWsConnectedToStudio = false
                }
            }
        }
    }

    private func sendStudioUpdate(type: String, payload: [String: Any]) {
        guard isWsConnectedToStudio, let task = wsTask else { return }
        let envelope: [String: Any] = [
            "type": type,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "payload": payload
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: envelope),
              let jsonStr = String(data: data, encoding: .utf8) else { return }
        task.send(.string(jsonStr)) { _ in }
    }

    private func sendPingCheck() {
        guard let task = wsTask else { return }
        let nowMs = Int(Date().timeIntervalSince1970 * 1000)
        let msg = "{\"type\":\"PING_CHECK\",\"timestamp\":\(nowMs)}"
        task.send(.string(msg)) { _ in }
    }

    private func handleIncomingServerJSON(_ rawText: String) {
        guard let data = rawText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        if type == "PONG_CHECK", let clientTs = json["clientTimestamp"] as? Int {
            let nowMs = Int(Date().timeIntervalSince1970 * 1000)
            wsPingMs = max(1, nowMs - clientTs)
            return
        }

        guard let payload = json["payload"] as? [String: Any] else { return }

        if type == "INIT_STATE" || type == "RUNDOWN_UPDATED" {
            let rawStories = (payload["rundown"] as? [[String: Any]]) ?? (payload["stories"] as? [[String: Any]])
            if let rawStories = rawStories,
               let storiesData = try? JSONSerialization.data(withJSONObject: rawStories),
               let decodedStories = try? JSONDecoder().decode([StoryItem].self, from: storiesData),
               !decodedStories.isEmpty {
                self.stories = decodedStories
            }
        }

        applyDictionaryToState(payload)
    }

    private func applyDictionaryToState(_ payload: [String: Any]) {
        if let storyId = payload["storyId"] as? String { state.storyId = storyId }
        if let scrollY = payload["scrollY"] as? Double {
            if Date().timeIntervalSince(lastManualScrubDate) > 0.12 {
                state.scrollY = max(0.0, scrollY)
            }
        } else if let scrollInt = payload["scrollY"] as? Int {
            if Date().timeIntervalSince(lastManualScrubDate) > 0.12 {
                state.scrollY = max(0.0, Double(scrollInt))
            }
        }
        if let speed = payload["speed"] as? Double { state.speed = speed }
        if let isPaused = payload["isPaused"] as? Bool { state.isPaused = isPaused }
        if let flipH = payload["flipH"] as? Bool { state.flipH = flipH }
        if let flipV = payload["flipV"] as? Bool { state.flipV = flipV }
        if let fontSize = payload["fontSizePx"] as? Double { state.fontSizePx = fontSize }
        if let margin = payload["marginPercent"] as? Double { state.marginPercent = margin }
        if let cue = payload["cueLinePercent"] as? Double { state.cueLinePercent = cue }
        if let text = payload["text"] as? String {
            state.text = text
            if let idx = stories.firstIndex(where: { $0.id == state.storyId }) {
                stories[idx].text = text
            }
        }
    }

    // MARK: - Servidor HTTP REST Nativo no Próprio iPhone (Ex: http://172.16.1.73:3000)
    // Permite controlar o iPhone diretamente pelo Bitfocus Companion, Stream Deck, vMix ou PC!
    private func startEmbeddedBroadcastServer(port: UInt16) {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
            let listener = try NWListener(using: params, on: nwPort)

            listener.stateUpdateHandler = { [weak self] newState in
                DispatchQueue.main.async {
                    self?.isEmbeddedServerRunning = (newState == .ready)
                    self?.deviceWiFiIP = Self.readLocalWiFiIPAddress() ?? "172.16.1.73"
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                DispatchQueue.main.async {
                    self?.handleEmbeddedConnection(connection)
                }
            }

            listener.start(queue: .main)
            self.nwListener = listener
        } catch {
            isEmbeddedServerRunning = false
        }
    }

    private func handleEmbeddedConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            DispatchQueue.main.async {
                guard let self = self, let data = data, let requestStr = String(data: data, encoding: .utf8) else {
                    connection.cancel()
                    return
                }
                self.processEmbeddedHttpRequest(requestStr, on: connection)
            }
        }
    }

    private func processEmbeddedHttpRequest(_ rawRequest: String, on connection: NWConnection) {
        let lines = rawRequest.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            connection.cancel()
            return
        }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            connection.cancel()
            return
        }
        let method = parts[0].uppercased()
        let path = parts[1]

        let bodyString = rawRequest.components(separatedBy: "\r\n\r\n").dropFirst().joined(separator: "\r\n\r\n")
        let bodyDict = (try? JSONSerialization.jsonObject(with: Data(bodyString.utf8))) as? [String: Any] ?? [:]

        if method == "POST" && path == "/api/transport/play-pause" {
            if let explicitPause = bodyDict["isPaused"] as? Bool {
                state.isPaused = explicitPause
            } else {
                state.isPaused.toggle()
            }
            sendEmbeddedJsonResponse(on: connection, dict: ["success": true, "isPaused": state.isPaused])
            return
        }

        if method == "POST" && path == "/api/transport/speed" {
            if let val = bodyDict["value"] as? Double {
                setSpeed(val)
            } else if let delta = bodyDict["delta"] as? Double {
                adjustSpeed(delta: delta)
            }
            sendEmbeddedJsonResponse(on: connection, dict: ["success": true, "speed": state.speed])
            return
        }

        if method == "POST" && path == "/api/transport/jump" {
            let target = bodyDict["target"] as? String ?? "top"
            if target == "top" {
                jumpToTop()
            } else if target == "next" {
                jumpToNextStory()
            } else if target == "prev" {
                jumpToPreviousStory()
            } else if let storyId = bodyDict["storyId"] as? String {
                selectStory(id: storyId, resetScroll: true)
            }
            sendEmbeddedJsonResponse(on: connection, dict: ["success": true, "storyId": state.storyId, "scrollY": state.scrollY])
            return
        }

        if method == "POST" && path == "/api/config/flip" {
            let axis = bodyDict["axis"] as? String ?? ""
            if axis == "horizontal" { toggleFlipHorizontal() }
            if axis == "vertical" { toggleFlipVertical() }
            sendEmbeddedJsonResponse(on: connection, dict: ["success": true, "flipH": state.flipH, "flipV": state.flipV])
            return
        }

        // GET /api/status ou raiz retorna o estado atual do Teleprompter iOS
        let statusDict: [String: Any] = [
            "status": "online",
            "device": detectedProfile.displayName,
            "ip": deviceWiFiIP,
            "isPaused": state.isPaused,
            "speed": state.speed,
            "scrollY": state.scrollY,
            "storyId": state.storyId
        ]
        sendEmbeddedJsonResponse(on: connection, dict: statusDict)
    }

    private func sendEmbeddedJsonResponse(on connection: NWConnection, dict: [String: Any]) {
        let bodyData = (try? JSONSerialization.data(withJSONObject: dict)) ?? Data("{}".utf8)
        let header =
            "HTTP/1.1 200 OK\r\n" +
            "Content-Type: application/json; charset=utf-8\r\n" +
            "Access-Control-Allow-Origin: *\r\n" +
            "Content-Length: \(bodyData.count)\r\n" +
            "Connection: close\r\n\r\n"
        var payload = Data(header.utf8)
        payload.append(bodyData)
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Suporte Nativo a Controle Bluetooth / Pedal / Gamepad (GameController.framework)
    private func setupGameControllerObservers() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.bindConnectedGamepad()
        }
        bindConnectedGamepad()
    }

    private func bindConnectedGamepad() {
        guard let controller = GCController.controllers().first else {
            connectedGamepadName = nil
            return
        }
        connectedGamepadName = controller.vendorName ?? "Controle Bluetooth"
        controller.extendedGamepad?.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                DispatchQueue.main.async {
                    self?.togglePlayPause()
                }
            }
        }
        controller.extendedGamepad?.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                DispatchQueue.main.async {
                    self?.jumpToPreviousStory()
                }
            }
        }
        controller.extendedGamepad?.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                DispatchQueue.main.async {
                    self?.jumpToNextStory()
                }
            }
        }
    }

    // MARK: - Leitura do IP Local Wi-Fi (en0) do iPhone (Ex: 172.16.1.73)
    static func readLocalWiFiIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        socklen_t(0),
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                }
            }
        }
        return address
    }
}

// Proxy sem ciclo de retenção para o CADisplayLink
private final class DisplayLinkProxy {
    weak var engine: BroadcastEngine?
    init(engine: BroadcastEngine) {
        self.engine = engine
    }
    @objc func onFrame(_ link: CADisplayLink) {
        engine?.stepDisplayFrame(timestamp: link.timestamp)
    }
}
