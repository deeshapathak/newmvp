//
//  MathUtils.swift
//  Rhinovate Capture
//
//  Mathematical utilities for face capture processing
//

import Foundation
import simd

struct MathUtils {
    /// Compute the translation delta between two transform matrices
    /// Returns the Euclidean distance between translation vectors
    static func computeTransformDelta(_ transform1: simd_float4x4, _ transform2: simd_float4x4) -> Float {
        let translation1 = simd_float3(transform1.columns.3.x, transform1.columns.3.y, transform1.columns.3.z)
        let translation2 = simd_float3(transform2.columns.3.x, transform2.columns.3.y, transform2.columns.3.z)
        return simd_length(translation1 - translation2)
    }
    
    /// Compute face normal from three vertices (triangle)
    static func computeTriangleNormal(_ v0: SIMD3<Float>, _ v1: SIMD3<Float>, _ v2: SIMD3<Float>) -> SIMD3<Float> {
        let edge1 = v1 - v0
        let edge2 = v2 - v0
        let normal = simd_cross(edge1, edge2)
        let length = simd_length(normal)
        return length > 0 ? normal / length : SIMD3<Float>(0, 0, 1)
    }
    
    /// Compute per-vertex normals by accumulating face normals
    /// vertices: array of vertex positions
    /// indices: array of triangle indices (triplets)
    /// Returns: array of normalized per-vertex normals
    static func computeVertexNormals(vertices: [SIMD3<Float>], indices: [UInt32]) -> [SIMD3<Float>] {
        var normals = Array(repeating: SIMD3<Float>(0, 0, 0), count: vertices.count)
        
        // Accumulate face normals for each vertex
        for i in stride(from: 0, to: indices.count, by: 3) {
            guard i + 2 < indices.count else { break }
            
            let i0 = Int(indices[i])
            let i1 = Int(indices[i + 1])
            let i2 = Int(indices[i + 2])
            
            guard i0 < vertices.count && i1 < vertices.count && i2 < vertices.count else { continue }
            
            let v0 = vertices[i0]
            let v1 = vertices[i1]
            let v2 = vertices[i2]
            
            let faceNormal = computeTriangleNormal(v0, v1, v2)
            
            normals[i0] += faceNormal
            normals[i1] += faceNormal
            normals[i2] += faceNormal
        }
        
        // Normalize all normals
        return normals.map { normal in
            let length = simd_length(normal)
            return length > 0 ? normal / length : SIMD3<Float>(0, 0, 1)
        }
    }
}

