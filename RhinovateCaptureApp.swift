//
//  RhinovateCaptureApp.swift
//  Rhinovate Capture
//
//  App entry point for Rhinovate Capture - 3D face mesh capture using TrueDepth camera
//

import SwiftUI

@main
struct RhinovateCaptureApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var captureManager = FaceCaptureManager()
    
    var body: some View {
        NavigationStack {
            if captureManager.capturedMesh != nil {
                PreviewView()
                    .environmentObject(captureManager)
            } else {
                CaptureView()
                    .environmentObject(captureManager)
            }
        }
    }
}

