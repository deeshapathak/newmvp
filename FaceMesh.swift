//
//  FaceMesh.swift
//  Rhinovate Capture
//
//  Data structure representing a captured 3D face mesh
//

import Foundation
import simd

/// Represents a 3D face mesh with vertices, normals, and indices
struct FaceMesh {
    /// Vertex positions in meters (SIMD3<Float> = vec3)
    let vertices: [SIMD3<Float>]
    
    /// Per-vertex normals (computed from triangle faces)
    let normals: [SIMD3<Float>]
    
    /// Triangle indices (UInt32 triplets)
    let indices: [UInt32]
    
    /// Initialize mesh with vertices and indices, computing normals automatically
    init(vertices: [SIMD3<Float>], indices: [UInt32]) {
        self.vertices = vertices
        self.indices = indices
        self.normals = MathUtils.computeVertexNormals(vertices: vertices, indices: indices)
    }
    
    /// Initialize mesh with pre-computed normals
    init(vertices: [SIMD3<Float>], normals: [SIMD3<Float>], indices: [UInt32]) {
        self.vertices = vertices
        self.normals = normals
        self.indices = indices
    }
    
    /// Validate mesh integrity
    var isValid: Bool {
        guard !vertices.isEmpty, !indices.isEmpty else { return false }
        guard vertices.count == normals.count else { return false }
        guard indices.count % 3 == 0 else { return false }
        
        // Check all indices are valid
        let maxIndex = vertices.count - 1
        return indices.allSatisfy { Int($0) <= maxIndex }
    }
}

