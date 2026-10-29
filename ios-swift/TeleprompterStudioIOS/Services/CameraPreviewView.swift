import AVFoundation
import SwiftUI
import UIKit

/// Camada nativa AVFoundation para câmera frontal TrueDepth (Eye-Contact Mode no iPhone 12 ao 17 Pro Max)
struct FrontCameraPreviewView: UIViewRepresentable {
    final class VideoPreviewUIView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        let captureSession = AVCaptureSession()

        func startCameraIfAuthorized() {
            guard !captureSession.isRunning else { return }
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted, let self = self else { return }
                DispatchQueue.global(qos: .userInitiated).async {
                    self.configureSession()
                    self.captureSession.startRunning()
                }
            }
        }

        private func configureSession() {
            captureSession.beginConfiguration()
            captureSession.sessionPreset = .high

            if captureSession.inputs.isEmpty,
               let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
               let input = try? AVCaptureDeviceInput(device: frontCamera),
               captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            captureSession.commitConfiguration()
            DispatchQueue.main.async {
                self.previewLayer.session = self.captureSession
                self.previewLayer.videoGravity = .resizeAspectFill
            }
        }

        func stopCamera() {
            if captureSession.isRunning {
                DispatchQueue.global(qos: .background).async {
                    self.captureSession.stopRunning()
                }
            }
        }
    }

    func makeUIView(context: Context) -> VideoPreviewUIView {
        let view = VideoPreviewUIView()
        view.backgroundColor = .black
        view.startCameraIfAuthorized()
        return view
    }

    func updateUIView(_ uiView: VideoPreviewUIView, context: Context) {}

    static func dismantleUIView(_ uiView: VideoPreviewUIView, coordinator: ()) {
        uiView.stopCamera()
    }
}

