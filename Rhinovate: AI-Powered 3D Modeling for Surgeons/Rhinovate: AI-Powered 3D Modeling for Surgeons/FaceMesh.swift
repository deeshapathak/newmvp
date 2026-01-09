//
//  FaceMesh.swift
//  Rhinovate Capture
//
//  Data structure representing a captured 3D face mesh
//

import Foundation
import simd
import UIKit

/// Represents a 3D face mesh with vertices, normals, UVs, and indices
struct FaceMesh {
    /// Vertex positions in meters (SIMD3<Float> = vec3)
    let vertices: [SIMD3<Float>]
    
    /// Per-vertex normals (computed from triangle faces)
    let normals: [SIMD3<Float>]
    
    /// UV coordinates (SIMD2<Float> = vec2) in [0,1] range
    let uvs: [SIMD2<Float>]
    
    /// Triangle indices (UInt32 triplets)
    let indices: [UInt32]
    
    /// Optional texture image
    var texture: UIImage?
    
    /// Initialize mesh with vertices and indices, computing normals and UVs automatically
    init(vertices: [SIMD3<Float>], indices: [UInt32]) {
        self.vertices = vertices
        self.indices = indices
        self.normals = MathUtils.computeVertexNormals(vertices: vertices, indices: indices)
        self.uvs = FaceUVMap.generateUVs(vertices: vertices)
        self.texture = nil
    }
    
    /// Initialize mesh with pre-computed normals and UVs
    init(vertices: [SIMD3<Float>], normals: [SIMD3<Float>], uvs: [SIMD2<Float>], indices: [UInt32], texture: UIImage? = nil) {
        self.vertices = vertices
        self.normals = normals
        self.uvs = uvs
        self.indices = indices
        self.texture = texture
    }
    
    /// Initialize mesh with texture
    init(vertices: [SIMD3<Float>], indices: [UInt32], texture: UIImage?) {
        self.vertices = vertices
        self.indices = indices
        self.normals = MathUtils.computeVertexNormals(vertices: vertices, indices: indices)
        self.uvs = FaceUVMap.generateUVs(vertices: vertices)
        self.texture = texture
    }
    
    /// Validate mesh integrity
    var isValid: Bool {
        guard !vertices.isEmpty, !indices.isEmpty else { return false }
        guard vertices.count == normals.count else { return false }
        guard vertices.count == uvs.count else { return false }
        guard indices.count % 3 == 0 else { return false }
        
        // Check all indices are valid
        let maxIndex = vertices.count - 1
        return indices.allSatisfy { Int($0) <= maxIndex }
    }
}

