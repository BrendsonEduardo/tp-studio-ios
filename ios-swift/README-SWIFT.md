# TP Studio iOS — Aplicativo Nativo em Swift & SwiftUI (iPhone 12 até 17 Pro Max)

Aplicativo **100% Nativo em Swift 5 / SwiftUI** projetado para toda a família **iPhone 12, 13, 14, 15, 16 e 17 (Mini, Standard, Plus, Pro e Pro Max)** com motor gráfico **`CADisplayLink` a 60Hz / 120Hz ProMotion**, câmera frontal **TrueDepth Eye-Contact (`AVFoundation`)**, servidor HTTP REST integrado no próprio iPhone (`Network.framework` na porta `3000` — ex: `http://172.16.1.73:3000`) e cliente WebSocket 60Hz.

---

## 1. Estrutura do Código-Fonte Swift (`ios-swift/`)

- [`TeleprompterStudioIOS.xcodeproj`](./TeleprompterStudioIOS.xcodeproj/project.pbxproj): Projeto oficial do Xcode pronto para abrir e compilar.
- [`TeleprompterStudioIOS/TeleprompterStudioApp.swift`](./TeleprompterStudioIOS/TeleprompterStudioApp.swift): Ponto de entrada `@main` do app SwiftUI com bloqueio automático de repouso de tela (`isIdleTimerDisabled = true`).
- [`TeleprompterStudioIOS/Models/PrompterModels.swift`](./TeleprompterStudioIOS/Models/PrompterModels.swift):
  - Estruturas `StoryItem` e `PrompterState`.
  - Enum `IPhoneHardwareProfile` com calibração óptica e detecção automática para **iPhone 12 Mini / 12 / 13 / 14 / 15 / 16 / 17 até o 17 Pro Max**.
  - Parser `BroadcastScriptFormatter` para destacar rubricas `[CORTA CÂMERA 1]`, `[CORTA GC]` e `[ENTRA VT]`.
- [`TeleprompterStudioIOS/Services/BroadcastEngine.swift`](./TeleprompterStudioIOS/Services/BroadcastEngine.swift):
  - **Motor `CADisplayLink` 60Hz / 120Hz ProMotion (`CAFrameRateRange`)** com interpolação LERP em tempo real.
  - **Servidor HTTP REST Nativo no iPhone (`NWListener` na porta `3000`)**: Permite que o PC, Bitfocus Companion, Stream Deck ou vMix disparem comandos diretamente para o IP do iPhone (`http://172.16.1.73:3000/api/transport/play-pause`, `/api/transport/speed`, `/api/transport/jump`, `/api/config/flip`).
  - **Cliente WebSocket (`URLSessionWebSocketTask`)**: Sincroniza em 60Hz com o servidor do PC quando desejado.
  - **Suporte Nativo a Controle Bluetooth / Pedal (`GameController.framework`)** e **Haptics (`UIImpactFeedbackGenerator`)**.
- [`TeleprompterStudioIOS/Services/CameraPreviewView.swift`](./TeleprompterStudioIOS/Services/CameraPreviewView.swift): Camada `AVCaptureVideoPreviewLayer` para exibir a câmera frontal TrueDepth por trás do texto.
- [`TeleprompterStudioIOS/Views/`](./TeleprompterStudioIOS/Views/):
  - [`MainTabView.swift`](./TeleprompterStudioIOS/Views/MainTabView.swift): Barra superior Tally (`NO AR` / `PAUSA`) adaptada ao Notch e Dynamic Island + 4 Abas nativas.
  - [`PrompterStageView.swift`](./TeleprompterStudioIOS/Views/PrompterStageView.swift): Tela de leitura OLED com gestos nativos (1 toque Play/Pause, 2 toques Modo Imersivo Tela Cheia, Drag vertical para Scrub/Jog, Pinch-to-Zoom com 2 dedos para fonte e espelhamento óptico `scaleEffect`).
  - [`CockpitControlView.swift`](./TeleprompterStudioIOS/Views/CockpitControlView.swift): Controle Master, trilha Jog/Shuttle Touch, Mini Monitor de Retorno e seletor de modelo do iPhone (12 ao 17 Pro Max).
  - [`RundownListView.swift`](./TeleprompterStudioIOS/Views/RundownListView.swift): Escaleta de laudas com contagem de palavras e tempo de leitura.
  - [`ScriptEditorAndNetworkView.swift`](./TeleprompterStudioIOS/Views/ScriptEditorAndNetworkView.swift): Editor em tempo real com chips de rubrica e configuração do servidor IP `172.16.1.73:3000`.

---

## 2. Como Compilar e Instalar no iPhone (`172.16.1.73`)

### Opção A: Usando um Mac com Xcode (Direto via Cabo ou Wi-Fi)
1. Copie a pasta `ios-swift` para o Mac e abra o arquivo `TeleprompterStudioIOS.xcodeproj` no **Xcode**.
2. No menu esquerdo do Xcode, clique em **TeleprompterStudioIOS** → aba **Signing & Capabilities**.
3. Marque **Automatically manage signing** e selecione seu **Team** (qualquer Apple ID gratuito funciona).
4. Conecte o iPhone (12 ao 17 Pro Max) via USB ou na mesma rede Wi-Fi (`172.16.1.73`), selecione seu iPhone no topo do Xcode e pressione **`Cmd + R` (Run)**.

### Opção B: Compilando no Windows (Sem ter um Mac físico)
Como o compilador oficial da Apple (`xcodebuild`) exige macOS, já deixamos pronto o workflow automático [`.github/workflows/build-ios-swift.yml`](../.github/workflows/build-ios-swift.yml):
1. Suba este projeto para um repositório no **GitHub** (pode ser privado).
2. Na aba **Actions** do GitHub, clique em **Build Native Swift iOS App (.ipa)** → **Run workflow**.
3. O servidor macOS da nuvem compilará o projeto Swift e gerará o arquivo **`TeleprompterStudioIOS.ipa`** para download.
4. No seu PC Windows, abra o utilitário gratuito **Sideloadly** (ou **AltStore**), conecte o iPhone via USB (ou Wi-Fi `172.16.1.73`), arraste o arquivo `TeleprompterStudioIOS.ipa` e clique em **Start** para instalar o app nativo no iPhone!

