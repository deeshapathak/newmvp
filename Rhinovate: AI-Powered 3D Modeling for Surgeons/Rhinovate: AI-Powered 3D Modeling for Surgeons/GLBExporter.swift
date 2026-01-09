//
//  GLBExporter.swift
//  Rhinovate Capture
//
//  Minimal glTF 2.0 binary (GLB) exporter implementation
//  Supports: single mesh, POSITION, NORMAL, INDICES
//

import Foundation
import simd
import UIKit

enum GLBExportError: LocalizedError {
    case invalidMesh
    case fileWriteError
    case bufferCreationError
    
    var errorDescription: String? {
        switch self {
        case .invalidMesh:
            return "Invalid mesh data"
        case .fileWriteError:
            return "Failed to write GLB file"
        case .bufferCreationError:
            return "Failed to create buffer data"
        }
    }
}

class GLBExporter {
    // GLB constants
    private let glbMagic: UInt32 = 0x46546C67 // "glTF"
    private let glbVersion: UInt32 = 2
    private let jsonChunkType: UInt32 = 0x4E4F534A // "JSON"
    private let binChunkType: UInt32 = 0x004E4942 // "BIN\0"
    
    /// Export face mesh to GLB file
    /// - Parameters:
    ///   - mesh: The face mesh to export
    ///   - filename: Output filename (default: "rhinovate_face.glb")
    /// - Returns: URL of exported file
    func export(mesh: FaceMesh, filename: String = "rhinovate_face.glb") throws -> URL {
        guard mesh.isValid else {
            throw GLBExportError.invalidMesh
        }
        
        // Get documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        // Create GLB structure
        let (jsonData, binData) = try createGLBData(from: mesh)
        
        // Write GLB file
        try writeGLBFile(jsonData: jsonData, binData: binData, to: fileURL)
        
        return fileURL
    }
    
    // MARK: - GLB Data Creation
    
    private func createGLBData(from mesh: FaceMesh) throws -> (jsonData: Data, binData: Data) {
        // Create binary buffer with interleaved vertex data
        // Format: [POSITION (vec3), NORMAL (vec3), TEXCOORD_0 (vec2)] for each vertex
        let vertexStride = MemoryLayout<Float>.size * 8 // 3 for position + 3 for normal + 2 for UV
        let vertexBufferSize = mesh.vertices.count * vertexStride
        var vertexBuffer = Data(capacity: vertexBufferSize)
        
        // Write interleaved vertex data
        for i in 0..<mesh.vertices.count {
            let position = mesh.vertices[i]
            let normal = mesh.normals[i]
            let uv = mesh.uvs[i]
            
            // Write position (vec3 Float32)
            withUnsafeBytes(of: position.x) { vertexBuffer.append(contentsOf: $0) }
            withUnsafeBytes(of: position.y) { vertexBuffer.append(contentsOf: $0) }
            withUnsafeBytes(of: position.z) { vertexBuffer.append(contentsOf: $0) }
            
            // Write normal (vec3 Float32)
            withUnsafeBytes(of: normal.x) { vertexBuffer.append(contentsOf: $0) }
            withUnsafeBytes(of: normal.y) { vertexBuffer.append(contentsOf: $0) }
            withUnsafeBytes(of: normal.z) { vertexBuffer.append(contentsOf: $0) }
            
            // Write UV (vec2 Float32)
            withUnsafeBytes(of: uv.x) { vertexBuffer.append(contentsOf: $0) }
            withUnsafeBytes(of: uv.y) { vertexBuffer.append(contentsOf: $0) }
        }
        
        // Create index buffer
        let indexBufferSize = mesh.indices.count * MemoryLayout<UInt32>.size
        var indexBuffer = Data(capacity: indexBufferSize)
        
        for index in mesh.indices {
            withUnsafeBytes(of: index) { indexBuffer.append(contentsOf: $0) }
        }
        
        // Combine buffers: vertex data first, then indices, then texture
        // Align to 4-byte boundary
        var binData = vertexBuffer
        let padding1 = (4 - (binData.count % 4)) % 4
        binData.append(Data(repeating: 0, count: padding1))
        
        let indexBufferOffset = binData.count
        binData.append(indexBuffer)
        
        let padding2 = (4 - (binData.count % 4)) % 4
        binData.append(Data(repeating: 0, count: padding2))
        
        // Add texture image if available
        var textureOffset: Int? = nil
        var textureSize: Int = 0
        var textureMimeType: String = "image/png"
        
        if let texture = mesh.texture,
           let textureData = texture.pngData() {
            textureOffset = binData.count
            textureSize = textureData.count
            binData.append(textureData)
            
            // Align texture to 4-byte boundary
            let padding3 = (4 - (binData.count % 4)) % 4
            binData.append(Data(repeating: 0, count: padding3))
            textureSize += padding3
        }
        
        // Compute min/max bounds from vertices
        let (minBounds, maxBounds) = computeBounds(vertices: mesh.vertices)
        
        // Create JSON structure
        let json = createJSONStructure(
            vertexCount: mesh.vertices.count,
            indexCount: mesh.indices.count,
            vertexBufferSize: vertexBuffer.count,
            indexBufferOffset: indexBufferOffset,
            minBounds: minBounds,
            maxBounds: maxBounds,
            hasTexture: textureOffset != nil,
            textureOffset: textureOffset ?? 0,
            textureSize: textureSize,
            textureMimeType: textureMimeType
        )
        
        guard let jsonData = json.data(using: .utf8) else {
            throw GLBExportError.bufferCreationError
        }
        
        return (jsonData, binData)
    }
    
    // MARK: - Bounds Computation
    
    private func computeBounds(vertices: [SIMD3<Float>]) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        guard !vertices.isEmpty else {
            return (SIMD3<Float>(-0.1, -0.1, -0.1), SIMD3<Float>(0.1, 0.1, 0.1))
        }
        
        var minBounds = vertices[0]
        var maxBounds = vertices[0]
        
        for vertex in vertices {
            minBounds.x = min(minBounds.x, vertex.x)
            minBounds.y = min(minBounds.y, vertex.y)
            minBounds.z = min(minBounds.z, vertex.z)
            maxBounds.x = max(maxBounds.x, vertex.x)
            maxBounds.y = max(maxBounds.y, vertex.y)
            maxBounds.z = max(maxBounds.z, vertex.z)
        }
        
        return (minBounds, maxBounds)
    }
    
    // MARK: - JSON Structure
    
    private func createJSONStructure(
        vertexCount: Int,
        indexCount: Int,
        vertexBufferSize: Int,
        indexBufferOffset: Int,
        minBounds: SIMD3<Float>,
        maxBounds: SIMD3<Float>,
        hasTexture: Bool,
        textureOffset: Int,
        textureSize: Int,
        textureMimeType: String
    ) -> String {
        // glTF 2.0 structure
        // Coordinate system: Right-handed, Y-up (glTF standard)
        // ARKit uses right-handed Y-up, so we use as-is
        
        // Build attributes JSON
        var attributesJSON = """
                    "POSITION": 0,
                    "NORMAL": 1,
                    "TEXCOORD_0": 3
        """
        
        // Build material JSON
        var materialJSON = ""
        if hasTexture {
            materialJSON = """
          "materials": [
            {
              "pbrMetallicRoughness": {
                "baseColorTexture": {
                  "index": 0
                },
                "metallicFactor": 0.0,
                "roughnessFactor": 0.5
              }
            }
          ],
          "textures": [
            {
              "sampler": 0,
              "source": 0
            }
          ],
          "samplers": [
            {
              "magFilter": 9729,
              "minFilter": 9729,
              "wrapS": 10497,
              "wrapT": 10497
            }
          ],
          "images": [
            {
              "mimeType": "\(textureMimeType)",
              "bufferView": 4
            }
          ],
"""
        }
        
        let totalBufferSize = vertexBufferSize + (indexCount * MemoryLayout<UInt32>.size) + ((4 - (vertexBufferSize % 4)) % 4) + (hasTexture ? textureSize : 0)
        
        let json = """
        {
          "asset": {
            "version": "2.0",
            "generator": "Rhinovate Capture"
          },
          "scene": 0,
          "scenes": [
            {
              "nodes": [0]
            }
          ],
          "nodes": [
            {
              "mesh": 0
            }
          ],
          "meshes": [
            {
              "primitives": [
                {
                  "attributes": {
                    \(attributesJSON)
                  },
                  "indices": 2\(hasTexture ? ",\n                  \"material\": 0" : "")
                }
              ]
            }
          ],
          "accessors": [
            {
              "bufferView": 0,
              "componentType": 5126,
              "count": \(vertexCount),
              "type": "VEC3",
              "max": [\(maxBounds.x), \(maxBounds.y), \(maxBounds.z)],
              "min": [\(minBounds.x), \(minBounds.y), \(minBounds.z)]
            },
            {
              "bufferView": 1,
              "componentType": 5126,
              "count": \(vertexCount),
              "type": "VEC3"
            },
            {
              "bufferView": 2,
              "componentType": 5125,
              "count": \(indexCount),
              "type": "SCALAR"
            },
            {
              "bufferView": 3,
              "componentType": 5126,
              "count": \(vertexCount),
              "type": "VEC2"
            }
          ],
          "bufferViews": [
            {
              "buffer": 0,
              "byteOffset": 0,
              "byteLength": \(vertexBufferSize),
              "byteStride": 32
            },
            {
              "buffer": 0,
              "byteOffset": 12,
              "byteLength": \(vertexBufferSize - 12),
              "byteStride": 32
            },
            {
              "buffer": 0,
              "byteOffset": \(indexBufferOffset),
              "byteLength": \(indexCount * MemoryLayout<UInt32>.size)
            },
            {
              "buffer": 0,
              "byteOffset": 24,
              "byteLength": \(vertexBufferSize - 24),
              "byteStride": 32
            }\(hasTexture ? ",\n            {\n              \"buffer\": 0,\n              \"byteOffset\": \(textureOffset),\n              \"byteLength\": \(textureSize)\n            }" : "")
          ],
          "buffers": [
            {
              "byteLength": \(totalBufferSize)
            }
          ]\(materialJSON.isEmpty ? "" : ",\n\(materialJSON)")
        }
        """
        
        return json
    }
    
    // MARK: - GLB File Writing
    
    private func writeGLBFile(jsonData: Data, binData: Data, to url: URL) throws {
        var glbData = Data()
        
        // Pad JSON to 4-byte boundary
        var paddedJSON = jsonData
        let jsonPadding = (4 - (paddedJSON.count % 4)) % 4
        paddedJSON.append(Data(repeating: 0x20, count: jsonPadding)) // Pad with spaces
        
        // Pad BIN to 4-byte boundary
        var paddedBIN = binData
        let binPadding = (4 - (paddedBIN.count % 4)) % 4
        paddedBIN.append(Data(repeating: 0, count: binPadding))
        
        // GLB Header (12 bytes)
        // Magic
        glbData.append(contentsOf: withUnsafeBytes(of: glbMagic.littleEndian) { Data($0) })
        // Version
        glbData.append(contentsOf: withUnsafeBytes(of: glbVersion.littleEndian) { Data($0) })
        // Total length (will update later)
        let totalLengthOffset = glbData.count
        glbData.append(contentsOf: withUnsafeBytes(of: UInt32(0).littleEndian) { Data($0) })
        
        // JSON Chunk
        let jsonChunkLength = UInt32(paddedJSON.count)
        glbData.append(contentsOf: withUnsafeBytes(of: jsonChunkLength.littleEndian) { Data($0) })
        glbData.append(contentsOf: withUnsafeBytes(of: jsonChunkType.littleEndian) { Data($0) })
        glbData.append(paddedJSON)
        
        // BIN Chunk
        let binChunkLength = UInt32(paddedBIN.count)
        glbData.append(contentsOf: withUnsafeBytes(of: binChunkLength.littleEndian) { Data($0) })
        glbData.append(contentsOf: withUnsafeBytes(of: binChunkType.littleEndian) { Data($0) })
        glbData.append(paddedBIN)
        
        // Update total length
        let totalLength = UInt32(glbData.count)
        withUnsafeBytes(of: totalLength.littleEndian) {
            glbData.replaceSubrange(totalLengthOffset..<totalLengthOffset + 4, with: $0)
        }
        
        // Write to file
        do {
            try glbData.write(to: url)
        } catch {
            throw GLBExportError.fileWriteError
        }
    }
}

