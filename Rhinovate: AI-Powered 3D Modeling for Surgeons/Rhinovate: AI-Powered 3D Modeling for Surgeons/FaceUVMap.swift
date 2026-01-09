//
//  FaceUVMap.swift
//  Rhinovate Capture
//
//  UV coordinate mapping for ARKit face mesh
//  Uses projection-based UV mapping since ARKit doesn't provide UVs
//

import Foundation
import simd

struct FaceUVMap {
    /// Generate UV coordinates for ARKit face mesh vertices
    /// Uses projection-based mapping: projects face-local coordinates to 2D UV space
    /// - Parameter vertices: Face mesh vertices in face-local coordinate system
    /// - Returns: Array of UV coordinates (vec2) in [0,1] range
    static func generateUVs(vertices: [SIMD3<Float>]) -> [SIMD2<Float>] {
        guard !vertices.isEmpty else { return [] }
        
        // Compute bounding box in face-local space
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
        
        // Project onto front-facing plane (x, y coordinates)
        // ARKit face mesh: x = left-right, y = up-down, z = forward-back
        // We'll use x,y for UV mapping with some padding
        let sizeX = maxBounds.x - minBounds.x
        let sizeY = maxBounds.y - minBounds.y
        
        // Add padding to avoid edge artifacts (10% padding)
        let padding: Float = 0.1
        let scaleX = (1.0 - 2 * padding) / sizeX
        let scaleY = (1.0 - 2 * padding) / sizeY
        
        // Use uniform scale to maintain aspect ratio
        let uniformScale = min(scaleX, scaleY)
        
        // Center the face in UV space
        let centerX = (minBounds.x + maxBounds.x) * 0.5
        let centerY = (minBounds.y + maxBounds.y) * 0.5
        
        var uvs: [SIMD2<Float>] = []
        uvs.reserveCapacity(vertices.count)
        
        for vertex in vertices {
            // Project to UV space
            let u = 0.5 + (vertex.x - centerX) * uniformScale
            let v = 0.5 - (vertex.y - centerY) * uniformScale // Flip Y for texture coordinates
            
            // Clamp to [0, 1]
            let clampedU = max(0.0, min(1.0, u))
            let clampedV = max(0.0, min(1.0, v))
            
            uvs.append(SIMD2<Float>(clampedU, clampedV))
        }
        
        return uvs
    }
    
    /// Alternative: Generate UVs with explicit bounds (for fine-tuning)
    static func generateUVs(vertices: [SIMD3<Float>], 
                            minBounds: SIMD3<Float>, 
                            maxBounds: SIMD3<Float>,
                            padding: Float = 0.1) -> [SIMD2<Float>] {
        guard !vertices.isEmpty else { return [] }
        
        let sizeX = maxBounds.x - minBounds.x
        let sizeY = maxBounds.y - minBounds.y
        
        guard sizeX > 0 && sizeY > 0 else {
            // Fallback to default generation
            return generateUVs(vertices: vertices)
        }
        
        let scaleX = (1.0 - 2 * padding) / sizeX
        let scaleY = (1.0 - 2 * padding) / sizeY
        let uniformScale = min(scaleX, scaleY)
        
        let centerX = (minBounds.x + maxBounds.x) * 0.5
        let centerY = (minBounds.y + maxBounds.y) * 0.5
        
        var uvs: [SIMD2<Float>] = []
        uvs.reserveCapacity(vertices.count)
        
        for vertex in vertices {
            let u = 0.5 + (vertex.x - centerX) * uniformScale
            let v = 0.5 - (vertex.y - centerY) * uniformScale
            
            let clampedU = max(0.0, min(1.0, u))
            let clampedV = max(0.0, min(1.0, v))
            
            uvs.append(SIMD2<Float>(clampedU, clampedV))
        }
        
        return uvs
    }
}

