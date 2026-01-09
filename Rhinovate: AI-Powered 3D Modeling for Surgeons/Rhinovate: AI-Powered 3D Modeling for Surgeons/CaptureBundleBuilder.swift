//
//  CaptureBundleBuilder.swift
//  Rhinovate Capture
//
//  Builds capture.zip bundle for cloud upload
//

import Foundation
import Compression

class CaptureBundleBuilder {
    private let tempDirectory: URL
    private let maxFrames: Int = 60
    private let jpegQuality: CGFloat = 0.7
    
    init() throws {
        // Create temp directory for bundle
        let tempDir = FileManager.default.temporaryDirectory
        let bundleDir = tempDir.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)
        self.tempDirectory = bundleDir
    }
    
    deinit {
        // Cleanup temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    /// Build capture.zip bundle
    /// - Parameters:
    ///   - mesh: Final averaged face mesh
    ///   - frames: Captured RGB frames with metadata
    ///   - faceTransform: Final face anchor transform
    /// - Returns: URL to capture.zip file
    func buildBundle(mesh: FaceMesh, frames: [(image: UIImage, metadata: CaptureFrame)], faceTransform: simd_float4x4) throws -> URL {
        // 1. Create manifest.json
        let manifest = createManifest(faceTransform: faceTransform)
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: tempDirectory.appendingPathComponent("manifest.json"))
        
        // 2. Create mesh.json
        let meshData = createMeshJSON(mesh: mesh)
        let meshDataEncoded = try JSONEncoder().encode(meshData)
        try meshDataEncoded.write(to: tempDirectory.appendingPathComponent("mesh.json"))
        
        // 3. Create frames directory and save frames
        let framesDir = tempDirectory.appendingPathComponent("frames")
        try FileManager.default.createDirectory(at: framesDir, withIntermediateDirectories: true)
        
        var frameMetadata: [CaptureFrame] = []
        let frameCount = min(frames.count, maxFrames)
        
        for i in 0..<frameCount {
            let frame = frames[i]
            let filename = String(format: "%04d.jpg", i + 1)
            let framePath = framesDir.appendingPathComponent(filename)
            
            // Save JPEG
            if let jpegData = frame.image.jpegData(compressionQuality: jpegQuality) {
                try jpegData.write(to: framePath)
                frameMetadata.append(frame.metadata)
            }
        }
        
        // 4. Create frames.jsonl
        let framesJSONL = frameMetadata.map { frame -> String in
            let encoder = JSONEncoder()
            encoder.outputFormatting = []
            if let data = try? encoder.encode(frame),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            return ""
        }.filter { !$0.isEmpty }.joined(separator: "\n")
        
        try framesJSONL.write(to: framesDir.appendingPathComponent("frames.jsonl"), atomically: true, encoding: .utf8)
        
        // 5. Create zip file using shell command (Foundation doesn't have built-in zip)
        let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent("capture_\(UUID().uuidString).zip")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", zipURL.path, "."]
        process.currentDirectoryPath = tempDirectory.path
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw CaptureBundleError.zipCreationFailed
            }
        } catch {
            throw CaptureBundleError.zipCreationFailed
        }
        
        return zipURL
    }
    
    private func createManifest(faceTransform: simd_float4x4) -> [String: Any] {
        let device = UIDevice.current
        return [
            "deviceModel": device.model,
            "iosVersion": device.systemVersion,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            "coordinateSystem": "right-handed-y-up",
            "units": "meters",
            "faceTransform": [
                "m00": faceTransform.columns.0.x,
                "m01": faceTransform.columns.0.y,
                "m02": faceTransform.columns.0.z,
                "m03": faceTransform.columns.0.w,
                "m10": faceTransform.columns.1.x,
                "m11": faceTransform.columns.1.y,
                "m12": faceTransform.columns.1.z,
                "m13": faceTransform.columns.1.w,
                "m20": faceTransform.columns.2.x,
                "m21": faceTransform.columns.2.y,
                "m22": faceTransform.columns.2.z,
                "m23": faceTransform.columns.2.w,
                "m30": faceTransform.columns.3.x,
                "m31": faceTransform.columns.3.y,
                "m32": faceTransform.columns.3.z,
                "m33": faceTransform.columns.3.w
            ]
        ]
    }
    
    private func createMeshJSON(mesh: FaceMesh) -> [String: Any] {
        var meshJSON: [String: Any] = [:]
        
        // Vertices
        meshJSON["vertices"] = mesh.vertices.map { ["x": $0.x, "y": $0.y, "z": $0.z] }
        
        // Indices
        meshJSON["indices"] = mesh.indices.map { Int($0) }
        
        // Normals (optional)
        meshJSON["normals"] = mesh.normals.map { ["x": $0.x, "y": $0.y, "z": $0.z] }
        
        return meshJSON
    }
}

enum CaptureBundleError: Error {
    case zipCreationFailed
    case frameSaveFailed
    case missingData
}

