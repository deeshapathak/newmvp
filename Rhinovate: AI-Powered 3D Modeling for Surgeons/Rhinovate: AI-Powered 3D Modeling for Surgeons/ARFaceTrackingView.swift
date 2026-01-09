//
//  ARFaceTrackingView.swift
//  Rhinovate Capture
//
//  SwiftUI wrapper for ARKit face tracking using RealityKit ARView
//

import SwiftUI
import ARKit
import RealityKit

struct ARFaceTrackingView: UIViewRepresentable {
    @ObservedObject var captureManager: FaceCaptureManager
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR session for face tracking
        let configuration = ARFaceTrackingConfiguration()
        configuration.isWorldTrackingEnabled = false // Only face tracking
        
        // Check if TrueDepth is supported
        guard ARFaceTrackingConfiguration.isSupported else {
            captureManager.checkTrueDepthSupport()
            return arView
        }
        
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        arView.session.delegate = context.coordinator
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(captureManager: captureManager)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        let captureManager: FaceCaptureManager
        
        init(captureManager: FaceCaptureManager) {
            self.captureManager = captureManager
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            // Get the current frame only when we need it, and don't retain it
            // Process immediately and let it be released
            let frame = session.currentFrame
            
            for anchor in anchors {
                if let faceAnchor = anchor as? ARFaceAnchor {
                    // Process immediately - don't store the frame
                    captureManager.processFaceAnchor(faceAnchor, frame: frame)
                }
            }
        }
        
        func session(_ session: ARSession, didFailWithError error: Error) {
            print("AR Session failed: \(error.localizedDescription)")
        }
        
        func sessionWasInterrupted(_ session: ARSession) {
            print("AR Session interrupted")
        }
        
        func sessionInterruptionEnded(_ session: ARSession) {
            print("AR Session interruption ended")
            // Restart session
            if let configuration = session.configuration as? ARFaceTrackingConfiguration {
                session.run(configuration, options: [.resetTracking])
            }
        }
    }
}

