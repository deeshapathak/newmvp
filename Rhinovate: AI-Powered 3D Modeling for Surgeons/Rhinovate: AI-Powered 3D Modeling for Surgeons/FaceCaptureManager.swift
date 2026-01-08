//
//  FaceCaptureManager.swift
//  Rhinovate Capture
//
//  Manages face capture session, quality filtering, and frame accumulation
//

import Foundation
import ARKit
import simd
import Combine

/// Observable manager for face capture operations
class FaceCaptureManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isTrueDepthSupported: Bool = false
    @Published var trackingState: ARTrackingState = .normal
    @Published var isExpressionNeutral: Bool = true
    @Published var isCapturing: Bool = false
    @Published var capturedFrames: Int = 0
    @Published var capturedMesh: FaceMesh?
    
    // MARK: - Capture Configuration
    private let captureDuration: TimeInterval = 2.0 // seconds
    private let minGoodFrames: Int = 20
    private let maxHeadMotionDelta: Float = 0.01 // meters
    private let expressionThresholds: [String: Float] = [
        "jawOpen": 0.1,
        "mouthSmileLeft": 0.3,
        "mouthSmileRight": 0.3,
        "browInnerUp": 0.3
    ]
    
    // MARK: - Private State
    private var captureStartTime: Date?
    private var acceptedFrames: [FaceFrame] = []
    private var lastAcceptedTransform: simd_float4x4?
    private var cachedIndices: [UInt32]?
    
    // MARK: - Face Frame Data
    struct FaceFrame {
        let vertices: [SIMD3<Float>]
        let transform: simd_float4x4
        let timestamp: Date
    }
    
    // MARK: - Tracking State
    enum ARTrackingState {
        case normal
        case limited
        case notAvailable
    }
    
    // MARK: - Initialization
    init() {
        checkTrueDepthSupport()
    }
    
    // MARK: - TrueDepth Support Check
    func checkTrueDepthSupport() {
        isTrueDepthSupported = ARFaceTrackingConfiguration.isSupported
    }
    
    // MARK: - Frame Processing
    func processFaceAnchor(_ anchor: ARFaceAnchor) {
        // Update tracking state
        if anchor.isTracked {
            trackingState = .normal
        } else {
            trackingState = .limited
        }
        
        // Check expression neutrality
        isExpressionNeutral = checkExpressionNeutrality(blendShapes: anchor.blendShapes)
        
        // If capturing, evaluate and potentially accept this frame
        if isCapturing {
            evaluateFrame(anchor: anchor)
        }
    }
    
    // MARK: - Expression Checking
    private func checkExpressionNeutrality(blendShapes: [ARFaceAnchor.BlendShapeLocation: NSNumber]) -> Bool {
        // Check each threshold key against blend shapes
        for (keyString, threshold) in expressionThresholds {
            // Try to find matching blend shape location
            var foundMatch = false
            for (blendShapeKey, value) in blendShapes {
                if blendShapeKey.rawValue == keyString {
                    if value.floatValue > threshold {
                        return false
                    }
                    foundMatch = true
                    break
                }
            }
            // If we have a threshold but no matching blend shape, that's okay (skip it)
        }
        return true
    }
    
    // MARK: - Frame Evaluation
    private func evaluateFrame(anchor: ARFaceAnchor) {
        guard let startTime = captureStartTime else { return }
        
        // Check if capture window has ended
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed >= captureDuration {
            finishCapture()
            return
        }
        
        // Quality checks
        guard trackingState == .normal else { return }
        guard isExpressionNeutral else { return }
        
        // Check head motion
        if let lastTransform = lastAcceptedTransform {
            let delta = MathUtils.computeTransformDelta(anchor.transform, lastTransform)
            guard delta <= maxHeadMotionDelta else { return }
        }
        
        // Extract vertices
        guard let vertices = extractVertices(from: anchor.geometry) else { return }
        
        // Cache indices on first frame
        if cachedIndices == nil {
            cachedIndices = extractIndices(from: anchor.geometry)
        }
        
        // Accept frame
        let frame = FaceFrame(
            vertices: vertices,
            transform: anchor.transform,
            timestamp: Date()
        )
        acceptedFrames.append(frame)
        lastAcceptedTransform = anchor.transform
        capturedFrames = acceptedFrames.count
        
        // Check if we have enough frames
        if acceptedFrames.count >= minGoodFrames && !isCapturing {
            // This shouldn't happen, but handle edge case
        }
    }
    
    // MARK: - Vertex Extraction
    private func extractVertices(from geometry: ARFaceGeometry) -> [SIMD3<Float>]? {
        // In iOS 17+, ARFaceGeometry.vertices is directly an array of SIMD3<Float>
        let vertices = geometry.vertices
        guard !vertices.isEmpty else { return nil }
        
        // Convert to our array format (already SIMD3<Float>)
        return Array(vertices)
    }
    
    // MARK: - Index Extraction
    private func extractIndices(from geometry: ARFaceGeometry) -> [UInt32]? {
        // In iOS 17+, ARFaceGeometry.triangleIndices is directly an array of Int16
        let triangleIndices = geometry.triangleIndices
        guard !triangleIndices.isEmpty else { return nil }
        
        // Convert Int16 array to UInt32 array
        return triangleIndices.map { UInt32($0) }
    }
    
    // MARK: - Capture Control
    func startCapture() {
        guard isTrueDepthSupported else { return }
        guard !isCapturing else { return }
        
        isCapturing = true
        captureStartTime = Date()
        acceptedFrames.removeAll()
        lastAcceptedTransform = nil
        cachedIndices = nil
        capturedFrames = 0
        capturedMesh = nil
    }
    
    func finishCapture() {
        guard isCapturing else { return }
        isCapturing = false
        
        // Check if we have enough frames
        guard acceptedFrames.count >= minGoodFrames else {
            // Reset for retry
            acceptedFrames.removeAll()
            capturedFrames = 0
            return
        }
        
        // Average vertices across all accepted frames
        guard let finalVertices = averageVertices(), let indices = cachedIndices else {
            acceptedFrames.removeAll()
            capturedFrames = 0
            return
        }
        
        // Create mesh
        capturedMesh = FaceMesh(vertices: finalVertices, indices: indices)
        
        // Cleanup
        acceptedFrames.removeAll()
        cachedIndices = nil
    }
    
    // MARK: - Vertex Averaging
    private func averageVertices() -> [SIMD3<Float>]? {
        guard let firstFrame = acceptedFrames.first else { return nil }
        let vertexCount = firstFrame.vertices.count
        
        var averagedVertices = Array(repeating: SIMD3<Float>(0, 0, 0), count: vertexCount)
        
        for frame in acceptedFrames {
            guard frame.vertices.count == vertexCount else { continue }
            for i in 0..<vertexCount {
                averagedVertices[i] += frame.vertices[i]
            }
        }
        
        let frameCount = Float(acceptedFrames.count)
        return averagedVertices.map { $0 / frameCount }
    }
    
    // MARK: - Reset
    func reset() {
        isCapturing = false
        captureStartTime = nil
        acceptedFrames.removeAll()
        lastAcceptedTransform = nil
        cachedIndices = nil
        capturedFrames = 0
        capturedMesh = nil
    }
}

