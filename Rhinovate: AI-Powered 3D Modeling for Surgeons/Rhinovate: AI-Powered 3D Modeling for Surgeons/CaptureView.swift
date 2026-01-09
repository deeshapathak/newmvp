//
//  CaptureView.swift
//  Rhinovate Capture
//
//  Main capture screen with AR face tracking and capture controls
//

import SwiftUI

struct CaptureView: View {
    @EnvironmentObject var captureManager: FaceCaptureManager
    @State private var showInsufficientFramesAlert = false
    
    var body: some View {
        ZStack {
            // AR View
            ARFaceTrackingView(captureManager: captureManager)
                .edgesIgnoringSafeArea(.all)
            
            // Overlay UI
            VStack {
                Spacer()
                
                // Status Panel
                VStack(spacing: 12) {
                    // TrueDepth Support
                    HStack {
                        Image(systemName: captureManager.isTrueDepthSupported ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(captureManager.isTrueDepthSupported ? .green : .red)
                        Text(captureManager.isTrueDepthSupported ? "TrueDepth supported" : "TrueDepth not supported")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    
                    // Tracking State
                    HStack {
                        Image(systemName: trackingIcon)
                            .foregroundColor(trackingColor)
                        Text("Tracking: \(trackingText)")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    
                    // Expression State
                    HStack {
                        Image(systemName: captureManager.isExpressionNeutral ? "face.smiling" : "face.dashed")
                            .foregroundColor(captureManager.isExpressionNeutral ? .green : .orange)
                        Text("Expression: \(captureManager.isExpressionNeutral ? "neutral" : "not neutral")")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    
                    // Distance Indicator
                    if let distance = captureManager.faceDistance {
                        HStack {
                            Image(systemName: distanceIcon(distance))
                                .foregroundColor(distanceColor(distance))
                            Text("Distance: \(distanceText(distance))")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                    }
                    
                    // Lighting Indicator
                    if let brightness = captureManager.averageBrightness {
                        HStack {
                            Image(systemName: brightnessIcon(brightness))
                                .foregroundColor(brightnessColor(brightness))
                            Text("Lighting: \(brightnessText(brightness))")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                    }
                    
                    // Capture Progress
                    if captureManager.isCapturing {
                        VStack(spacing: 4) {
                            Text("Capturing...")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Frames: \(captureManager.capturedFrames)")
                                .font(.caption)
                                .foregroundColor(.white)
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                    }
                }
                .padding()
                
                // Control Buttons
                VStack(spacing: 16) {
                    // Start Capture Button
                    Button(action: {
                        captureManager.startCapture()
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Start Capture (2s)")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(captureManager.isTrueDepthSupported && !captureManager.isCapturing ? Color.blue : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!captureManager.isTrueDepthSupported || captureManager.isCapturing)
                    
                    // Finish Button
                    Button(action: {
                        captureManager.finishCapture()
                        if captureManager.capturedMesh == nil {
                            showInsufficientFramesAlert = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Finish")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(captureManager.isCapturing ? Color.green : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!captureManager.isCapturing)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Capture")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Insufficient Frames", isPresented: $showInsufficientFramesAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again. Hold a neutral expression and keep your head still for 2 seconds.")
        }
    }
    
    private var trackingIcon: String {
        switch captureManager.trackingState {
        case .normal:
            return "checkmark.circle.fill"
        case .limited:
            return "exclamationmark.triangle.fill"
        case .notAvailable:
            return "xmark.circle.fill"
        }
    }
    
    private var trackingColor: Color {
        switch captureManager.trackingState {
        case .normal:
            return .green
        case .limited:
            return .orange
        case .notAvailable:
            return .red
        }
    }
    
    private var trackingText: String {
        switch captureManager.trackingState {
        case .normal:
            return "normal"
        case .limited:
            return "limited"
        case .notAvailable:
            return "not available"
        }
    }
    
    // MARK: - Distance Helpers
    private func distanceIcon(_ distance: Float) -> String {
        if distance < 0.3 {
            return "arrow.down.circle.fill" // Too close
        } else if distance > 0.7 {
            return "arrow.up.circle.fill" // Too far
        } else {
            return "checkmark.circle.fill" // Good
        }
    }
    
    private func distanceColor(_ distance: Float) -> Color {
        if distance < 0.3 {
            return .orange
        } else if distance > 0.7 {
            return .orange
        } else {
            return .green
        }
    }
    
    private func distanceText(_ distance: Float) -> String {
        if distance < 0.3 {
            return "too close"
        } else if distance > 0.7 {
            return "too far"
        } else {
            return "good"
        }
    }
    
    // MARK: - Brightness Helpers
    private func brightnessIcon(_ brightness: Float) -> String {
        if brightness < 0.3 {
            return "lightbulb.slash.fill"
        } else if brightness > 0.7 {
            return "lightbulb.fill"
        } else {
            return "lightbulb"
        }
    }
    
    private func brightnessColor(_ brightness: Float) -> Color {
        if brightness < 0.3 {
            return .orange
        } else if brightness > 0.7 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private func brightnessText(_ brightness: Float) -> String {
        if brightness < 0.3 {
            return "too dark"
        } else if brightness > 0.7 {
            return "bright"
        } else {
            return "good"
        }
    }
}

