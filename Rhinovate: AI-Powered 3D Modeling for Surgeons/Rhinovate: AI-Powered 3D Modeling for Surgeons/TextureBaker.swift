//
//  TextureBaker.swift
//  Rhinovate Capture
//
//  Bakes texture from captured RGB frames onto face mesh UV map
//

import Foundation
import UIKit
import ARKit
import simd

struct CapturedFrame {
    let image: UIImage
    let cameraTransform: simd_float4x4
    let cameraIntrinsics: simd_float3x3
    let faceTransform: simd_float4x4
    let timestamp: Date
    let trackingQuality: Float // 0.0 to 1.0
    let headRotation: Float // Magnitude of rotation (lower is better)
    let expressionScore: Float // Neutral expression score (higher is better)
    
    /// Combined quality score (higher is better)
    var qualityScore: Float {
        return trackingQuality * 0.4 + (1.0 - headRotation / Float.pi) * 0.3 + expressionScore * 0.3
    }
}

class TextureBaker {
    private let textureSize: Int = 1024 // 1024x1024 texture (reduced for performance)
    
    /// Bake texture from captured frames onto mesh
    /// - Parameters:
    ///   - mesh: Face mesh with vertices and UVs
    ///   - frames: Captured RGB frames with camera data
    /// - Returns: Baked texture image
    func bakeTexture(mesh: FaceMesh, frames: [CapturedFrame]) -> UIImage? {
        guard !frames.isEmpty else { 
            print("TextureBaker: No frames provided")
            return nil 
        }
        
        print("TextureBaker: Processing \(frames.count) frames")
        
        // Select best frame(s) for texturing
        let bestFrames = selectBestFrames(frames, count: min(3, frames.count))
        print("TextureBaker: Selected \(bestFrames.count) best frames")
        
        // Create texture canvas
        let size = CGSize(width: textureSize, height: textureSize)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        
        // Fill with a light gray background instead of black (helps see if texture is working)
        context.setFillColor(UIColor(white: 0.3, alpha: 1.0).cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Project vertices from each best frame
        var totalProjected = 0
        for frame in bestFrames {
            let projected = projectFrameOntoTexture(context: context, mesh: mesh, frame: frame, size: size)
            totalProjected += projected
        }
        
        print("TextureBaker: Total projected vertices: \(totalProjected)")
        
        // Fill holes using dilation
        let textureImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Verify texture has some color (not all gray/black)
        if let image = textureImage, let cgImage = image.cgImage {
            let width = cgImage.width
            let height = cgImage.height
            let sampleCount = min(100, width * height / 100) // Sample 1% of pixels
            var nonGrayCount = 0
            
            if let pixelData = cgImage.dataProvider?.data,
               let data = CFDataGetBytePtr(pixelData) {
                let bytesPerPixel = cgImage.bitsPerPixel / 8
                let bytesPerRow = cgImage.bytesPerRow
                
                for _ in 0..<sampleCount {
                    let x = Int.random(in: 0..<width)
                    let y = Int.random(in: 0..<height)
                    let index = y * bytesPerRow + x * bytesPerPixel
                    
                    if index + 2 < CFDataGetLength(pixelData) {
                        let r = data[index]
                        let g = data[index + 1]
                        let b = data[index + 2]
                        // Check if not gray (all channels similar) and not too dark
                        let maxDiff = max(abs(Int(r) - Int(g)), abs(Int(g) - Int(b)), abs(Int(r) - Int(b)))
                        if maxDiff > 10 && (Int(r) + Int(g) + Int(b)) > 30 {
                            nonGrayCount += 1
                        }
                    }
                }
            }
            
            print("TextureBaker: Texture has \(nonGrayCount)/\(sampleCount) non-gray samples")
        }
        
        return fillHoles(in: textureImage)
    }
    
    /// Select best frames based on quality scores
    private func selectBestFrames(_ frames: [CapturedFrame], count: Int) -> [CapturedFrame] {
        return frames.sorted { $0.qualityScore > $1.qualityScore }.prefix(count).map { $0 }
    }
    
    /// Project a single frame onto the texture
    /// Returns: Number of vertices successfully projected
    @discardableResult
    private func projectFrameOntoTexture(context: CGContext, mesh: FaceMesh, frame: CapturedFrame, size: CGSize) -> Int {
        let image = frame.image
        let imageSize = image.size
        guard let cgImage = image.cgImage else { 
            print("TextureBaker: Failed to get CGImage")
            return 0
        }
        
        // Get pixel data - use direct pixel access
        guard let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else { 
            print("TextureBaker: Failed to get pixel data")
            return 0
        }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        let pixelFormat = cgImage.bitmapInfo
        
        // Determine pixel format (BGRA or RGBA)
        let isBGRA = (pixelFormat.rawValue & CGBitmapInfo.byteOrder32Little.rawValue) != 0
        
        // Transform from face-local space to world space, then to camera space
        let faceToWorld = frame.faceTransform
        let worldToCamera = simd_inverse(frame.cameraTransform)
        
        var projectedCount = 0
        var validSamples = 0
        
        // Project each vertex
        for i in 0..<mesh.vertices.count {
            let vertex = mesh.vertices[i]
            let uv = mesh.uvs[i]
            
            // Transform vertex from face-local to world space, then to camera space
            let vertexHomogeneous = SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0)
            let worldSpace = faceToWorld * vertexHomogeneous
            let cameraSpace = worldToCamera * worldSpace
            
            // Skip if behind camera
            guard cameraSpace.z > 0.1 else { continue } // At least 10cm in front
            
            // Project to 2D using camera intrinsics
            // Note: intrinsics are for original image size, but we resized the image
            // We need to scale them
            let originalImageWidth: Float = 1920.0 // Typical front camera width
            let scaleFactor = Float(imageSize.width) / originalImageWidth
            
            let fx = frame.cameraIntrinsics[0][0] * scaleFactor
            let fy = frame.cameraIntrinsics[1][1] * scaleFactor
            let cx = frame.cameraIntrinsics[2][0] * scaleFactor
            let cy = frame.cameraIntrinsics[2][1] * scaleFactor
            
            let x2d = (cameraSpace.x / cameraSpace.z) * fx + cx
            let y2d = (cameraSpace.y / cameraSpace.z) * fy + cy
            
            // Check if within image bounds
            guard x2d >= 0 && x2d < Float(imageSize.width) &&
                  y2d >= 0 && y2d < Float(imageSize.height) else { continue }
            
            projectedCount += 1
            
            // Sample pixel color
            let pixelX = Int(x2d)
            let pixelY = Int(y2d)
            let pixelIndex = pixelY * bytesPerRow + pixelX * bytesPerPixel
            
            guard pixelIndex >= 0 && pixelIndex + 2 < CFDataGetLength(pixelData) else { continue }
            
            // Read RGB - handle BGRA format
            let r: CGFloat
            let g: CGFloat
            let b: CGFloat
            
            if isBGRA {
                // BGRA format
                b = CGFloat(data[pixelIndex]) / 255.0
                g = CGFloat(data[pixelIndex + 1]) / 255.0
                r = CGFloat(data[pixelIndex + 2]) / 255.0
            } else {
                // RGBA format
                r = CGFloat(data[pixelIndex]) / 255.0
                g = CGFloat(data[pixelIndex + 1]) / 255.0
                b = CGFloat(data[pixelIndex + 2]) / 255.0
            }
            
            // Skip if pixel is too dark (likely invalid)
            let brightness = (r + g + b) / 3.0
            guard brightness > 0.1 else { continue }
            
            validSamples += 1
            
            // Write to texture at UV location
            let textureX = CGFloat(uv.x) * size.width
            let textureY = CGFloat(uv.y) * size.height
            
            // Draw larger circle for better coverage
            let radius: CGFloat = 8.0
            context.setFillColor(UIColor(red: r, green: g, blue: b, alpha: 1.0).cgColor)
            context.fillEllipse(in: CGRect(
                x: textureX - radius,
                y: textureY - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }
        
        print("TextureBaker: Projected \(projectedCount) vertices, \(validSamples) valid samples")
        return validSamples
    }
    
    /// Fill holes in texture using simple dilation (optimized)
    private func fillHoles(in image: UIImage?) -> UIImage? {
        guard let image = image,
              let cgImage = image.cgImage else { return image }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // For MVP, use a simpler approach: just return the image with splatted pixels
        // Full hole-filling is too slow. The splatting should cover most areas.
        // If needed, we can add a lightweight blur pass instead
        
        // Simple approach: apply a light blur to smooth out gaps
        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return image }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(2.0, forKey: kCIInputRadiusKey) // Light blur
        
        guard let outputImage = filter.outputImage else { return image }
        let context = CIContext()
        guard let blurredCGImage = context.createCGImage(outputImage, from: outputImage.extent) else { return image }
        
        return UIImage(cgImage: blurredCGImage)
    }
}

