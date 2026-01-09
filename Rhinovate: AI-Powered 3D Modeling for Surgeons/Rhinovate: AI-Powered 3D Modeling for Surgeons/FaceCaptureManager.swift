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
import UIKit
import CoreImage
import CoreVideo

/// Observable manager for face capture operations
class FaceCaptureManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isTrueDepthSupported: Bool = false
    @Published var trackingState: ARTrackingState = .normal
    @Published var isExpressionNeutral: Bool = true
    @Published var isCapturing: Bool = false
    @Published var capturedFrames: Int = 0
    @Published var capturedMesh: FaceMesh?
    @Published var capturedColorFramesCount: Int = 0
    @Published var faceDistance: Float? // Distance in meters
    @Published var averageBrightness: Float? // 0.0 to 1.0
    
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
    private var capturedColorFrames: [CapturedFrame] = [] // For local texture baking
    private var cloudCaptureFrames: [(image: UIImage, metadata: CaptureFrame)] = [] // For cloud upload
    private var lastAcceptedTransform: simd_float4x4?
    private var cachedIndices: [UInt32]?
    private var finalFaceTransform: simd_float4x4?
    
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
    func processFaceAnchor(_ anchor: ARFaceAnchor, frame: ARFrame? = nil) {
        // Update tracking state
        if anchor.isTracked {
            trackingState = .normal
        } else {
            trackingState = .limited
        }
        
        // Check expression neutrality
        isExpressionNeutral = checkExpressionNeutrality(blendShapes: anchor.blendShapes)
        
        // Update face distance (z-component of transform)
        if let arFrame = frame {
            let facePosition = simd_float3(anchor.transform.columns.3.x, anchor.transform.columns.3.y, anchor.transform.columns.3.z)
            let cameraPosition = simd_float3(arFrame.camera.transform.columns.3.x, arFrame.camera.transform.columns.3.y, arFrame.camera.transform.columns.3.z)
            let distance = simd_length(facePosition - cameraPosition)
            faceDistance = distance
            
            // Estimate brightness from camera image (only when not capturing to avoid blocking)
            if !isCapturing {
                let pixelBuffer = arFrame.capturedImage
                averageBrightness = estimateBrightness(from: pixelBuffer)
            }
        }
        
        // If capturing, evaluate and potentially accept this frame
        if isCapturing {
            evaluateFrame(anchor: anchor, arFrame: frame)
        }
    }
    
    // MARK: - Brightness Estimation
    private func estimateBrightness(from pixelBuffer: CVPixelBuffer) -> Float? {
        // Quick brightness estimation - sample very sparsely to avoid blocking
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        // Sample very sparsely for performance (10x10 grid max)
        let sampleStep = max(1, min(width, height) / 10)
        var totalBrightness: Float = 0
        var sampleCount = 0
        
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                let offset = y * bytesPerRow + x * 4 // Assuming BGRA
                guard offset + 2 < bytesPerRow * height else { continue }
                
                // Convert to grayscale (simple luminance)
                let b = Float(buffer[offset])
                let g = Float(buffer[offset + 1])
                let r = Float(buffer[offset + 2])
                let brightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
                
                totalBrightness += brightness
                sampleCount += 1
                
                // Limit samples to avoid blocking
                if sampleCount >= 100 { break }
            }
            if sampleCount >= 100 { break }
        }
        
        return sampleCount > 0 ? totalBrightness / Float(sampleCount) : nil
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
    private func evaluateFrame(anchor: ARFaceAnchor, arFrame: ARFrame?) {
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
        
        // Capture color frame for local texture baking (sample every 5th frame)
        if let arFrame = arFrame, acceptedFrames.count % 5 == 0 {
            captureColorFrame(anchor: anchor, arFrame: arFrame)
            if capturedColorFrames.count == 1 {
                print("FaceCaptureManager: First color frame captured")
            }
        }
        
        // Capture frame for cloud processing (throttle to ~10-15 fps, every 3rd accepted frame)
        if let arFrame = arFrame, acceptedFrames.count % 3 == 0 {
            captureCloudFrame(anchor: anchor, arFrame: arFrame)
        }
        
        // Check if we have enough frames
        if acceptedFrames.count >= minGoodFrames && !isCapturing {
            // This shouldn't happen, but handle edge case
        }
    }
    
    // MARK: - Color Frame Capture
    private func captureColorFrame(anchor: ARFaceAnchor, arFrame: ARFrame) {
        // Extract data immediately and synchronously - don't retain ARFrame
        // Extract camera image immediately
        let pixelBuffer = arFrame.capturedImage
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        // Resize image to reduce memory (scale down for texture baking)
        let maxDimension: CGFloat = 512 // Limit image size
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scale = min(maxDimension / imageSize.width, maxDimension / imageSize.height, 1.0)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(scaledSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let scaledContext = UIGraphicsGetCurrentContext() else { return }
        scaledContext.draw(cgImage, in: CGRect(origin: .zero, size: scaledSize))
        guard let scaledCGImage = scaledContext.makeImage() else { return }
        let uiImage = UIImage(cgImage: scaledCGImage, scale: 1.0, orientation: .right)
        
        // Extract camera intrinsics (copy values, don't retain frame)
        let intrinsics = arFrame.camera.intrinsics
        let cameraIntrinsics = simd_float3x3(
            SIMD3<Float>(intrinsics[0][0], intrinsics[0][1], intrinsics[0][2]),
            SIMD3<Float>(intrinsics[1][0], intrinsics[1][1], intrinsics[1][2]),
            SIMD3<Float>(intrinsics[2][0], intrinsics[2][1], intrinsics[2][2])
        )
        
        // Copy transform (don't retain frame)
        let cameraTransform = arFrame.camera.transform
        
        // Compute head rotation magnitude
        let rotation = simd_quatf(anchor.transform)
        let headRotation = abs(rotation.angle)
        
        // Compute expression score (neutral = 1.0)
        let expressionScore: Float = checkExpressionNeutrality(blendShapes: anchor.blendShapes) ? 1.0 : 0.5
        
        // Tracking quality (1.0 if tracked, 0.5 if limited)
        let trackingQuality: Float = anchor.isTracked ? 1.0 : 0.5
        
        let capturedFrame = CapturedFrame(
            image: uiImage,
            cameraTransform: cameraTransform,
            cameraIntrinsics: cameraIntrinsics,
            faceTransform: anchor.transform,
            timestamp: Date(),
            trackingQuality: trackingQuality,
            headRotation: headRotation,
            expressionScore: expressionScore
        )
        
        capturedColorFrames.append(capturedFrame)
        capturedColorFramesCount = capturedColorFrames.count
        
        // Limit number of stored frames to prevent memory issues
        if capturedColorFrames.count > 10 {
            capturedColorFrames.removeFirst() // Keep only last 10 frames
        }
    }
    
    // MARK: - Cloud Frame Capture
    private func captureCloudFrame(anchor: ARFaceAnchor, arFrame: ARFrame) {
        // Capture full-resolution JPEG for cloud processing
        let pixelBuffer = arFrame.capturedImage
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        // Keep full resolution for cloud processing (don't resize)
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
        
        // Compute quality score
        let rotation = simd_quatf(anchor.transform)
        let headRotation = abs(rotation.angle)
        let expressionScore: Float = checkExpressionNeutrality(blendShapes: anchor.blendShapes) ? 1.0 : 0.5
        let trackingQuality: Float = anchor.isTracked ? 1.0 : 0.5
        let qualityScore = trackingQuality * 0.4 + (1.0 - headRotation / Float.pi) * 0.3 + expressionScore * 0.3
        
        // Create metadata
        let filename = String(format: "%04d.jpg", cloudCaptureFrames.count + 1)
        let metadata = CaptureFrame.from(
            arFrame: arFrame,
            faceAnchor: anchor,
            image: uiImage,
            filename: filename,
            qualityScore: qualityScore
        )
        
        cloudCaptureFrames.append((image: uiImage, metadata: metadata))
        
        // Limit to max 60 frames
        if cloudCaptureFrames.count > 60 {
            cloudCaptureFrames.removeFirst()
        }
    }
    
    // MARK: - Build Capture Bundle
    func buildCaptureBundle() throws -> URL {
        guard let mesh = capturedMesh,
              let faceTransform = finalFaceTransform else {
            throw CaptureBundleError.missingData
        }
        
        let builder = try CaptureBundleBuilder()
        return try builder.buildBundle(mesh: mesh, frames: cloudCaptureFrames, faceTransform: faceTransform)
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
        capturedColorFrames.removeAll()
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
            capturedColorFrames.removeAll()
            capturedFrames = 0
            return
        }
        
        // Average vertices across all accepted frames
        guard let finalVertices = averageVertices(), let indices = cachedIndices else {
            acceptedFrames.removeAll()
            capturedColorFrames.removeAll()
            capturedFrames = 0
            return
        }
        
        // Store final face transform
        finalFaceTransform = acceptedFrames.last?.transform
        
        // Create base mesh
        var mesh = FaceMesh(vertices: finalVertices, indices: indices)
        
        // Store mesh immediately (without texture) so UI can update
        capturedMesh = mesh
        
        // Bake texture asynchronously if we have color frames
        if !capturedColorFrames.isEmpty {
            print("FaceCaptureManager: Starting texture bake with \(capturedColorFrames.count) frames")
            
            // Copy frames to avoid retaining the manager's array
            let framesToProcess = capturedColorFrames
            let meshVertices = mesh.vertices
            let meshNormals = mesh.normals
            let meshUVs = mesh.uvs
            let meshIndices = mesh.indices
            
            DispatchQueue.global(qos: .userInitiated).async {
                let textureBaker = TextureBaker()
                let tempMesh = FaceMesh(vertices: meshVertices, normals: meshNormals, uvs: meshUVs, indices: meshIndices)
                
                if let texture = textureBaker.bakeTexture(mesh: tempMesh, frames: framesToProcess) {
                    print("FaceCaptureManager: Texture baked successfully, size: \(texture.size)")
                    
                    let texturedMesh = FaceMesh(
                        vertices: meshVertices,
                        normals: meshNormals,
                        uvs: meshUVs,
                        indices: meshIndices,
                        texture: texture
                    )
                    
                    // Update mesh with texture on main thread
                    DispatchQueue.main.async { [weak self] in
                        self?.capturedMesh = texturedMesh
                        print("FaceCaptureManager: Mesh updated with texture")
                    }
                } else {
                    print("FaceCaptureManager: Texture baking failed")
                }
            }
        } else {
            print("FaceCaptureManager: No color frames to bake texture from")
        }
        
        // Cleanup
        acceptedFrames.removeAll()
        capturedColorFrames.removeAll()
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
        capturedColorFrames.removeAll()
        cloudCaptureFrames.removeAll()
        lastAcceptedTransform = nil
        finalFaceTransform = nil
        cachedIndices = nil
        capturedFrames = 0
        capturedMesh = nil
    }
}

