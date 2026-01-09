//
//  CaptureFrame.swift
//  Rhinovate Capture
//
//  Represents a captured RGB frame with metadata for cloud processing
//

import Foundation
import ARKit
import simd
import UIKit

/// Captured frame metadata for cloud processing
struct CaptureFrame: Codable {
    let filename: String
    let timestamp: TimeInterval
    let width: Int
    let height: Int
    let cameraIntrinsics: CameraIntrinsics
    let faceTransform: Transform4x4
    let cameraTransform: Transform4x4
    let qualityScore: Float
    
    struct CameraIntrinsics: Codable {
        let fx: Float
        let fy: Float
        let cx: Float
        let cy: Float
    }
    
    struct Transform4x4: Codable {
        let m00: Float
        let m01: Float
        let m02: Float
        let m03: Float
        let m10: Float
        let m11: Float
        let m12: Float
        let m13: Float
        let m20: Float
        let m21: Float
        let m22: Float
        let m23: Float
        let m30: Float
        let m31: Float
        let m32: Float
        let m33: Float
        
        init(from matrix: simd_float4x4) {
            m00 = matrix.columns.0.x
            m01 = matrix.columns.0.y
            m02 = matrix.columns.0.z
            m03 = matrix.columns.0.w
            m10 = matrix.columns.1.x
            m11 = matrix.columns.1.y
            m12 = matrix.columns.1.z
            m13 = matrix.columns.1.w
            m20 = matrix.columns.2.x
            m21 = matrix.columns.2.y
            m22 = matrix.columns.2.z
            m23 = matrix.columns.2.w
            m30 = matrix.columns.3.x
            m31 = matrix.columns.3.y
            m32 = matrix.columns.3.z
            m33 = matrix.columns.3.w
        }
        
        func toMatrix() -> simd_float4x4 {
            return simd_float4x4(
                SIMD4<Float>(m00, m01, m02, m03),
                SIMD4<Float>(m10, m11, m12, m13),
                SIMD4<Float>(m20, m21, m22, m23),
                SIMD4<Float>(m30, m31, m32, m33)
            )
        }
    }
    
    static func from(arFrame: ARFrame, faceAnchor: ARFaceAnchor, image: UIImage, filename: String, qualityScore: Float) -> CaptureFrame {
        let intrinsics = arFrame.camera.intrinsics
        return CaptureFrame(
            filename: filename,
            timestamp: arFrame.timestamp,
            width: Int(image.size.width),
            height: Int(image.size.height),
            cameraIntrinsics: CameraIntrinsics(
                fx: intrinsics[0][0],
                fy: intrinsics[1][1],
                cx: intrinsics[2][0],
                cy: intrinsics[2][1]
            ),
            faceTransform: Transform4x4(from: faceAnchor.transform),
            cameraTransform: Transform4x4(from: arFrame.camera.transform),
            qualityScore: qualityScore
        )
    }
}

