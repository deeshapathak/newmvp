//
//  APIClient.swift
//  Rhinovate Capture
//
//  Client for Cloudflare Workers API
//

import Foundation

struct APIClient {
    let baseURL: String
    let apiKey: String?
    
    init(baseURL: String, apiKey: String? = nil) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
    
    // MARK: - Create Capture
    func createCapture() async throws -> CreateCaptureResponse {
        var request = URLRequest(url: URL(string: "\(baseURL)/v1/captures")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw APIError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        return try JSONDecoder().decode(CreateCaptureResponse.self, from: data)
    }
    
    // MARK: - Complete Upload
    func completeUpload(captureId: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/v1/captures/\(captureId)/complete")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw APIError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
    
    // MARK: - Get Status
    func getStatus(captureId: String) async throws -> CaptureStatus {
        var request = URLRequest(url: URL(string: "\(baseURL)/v1/captures/\(captureId)/status")!)
        request.httpMethod = "GET"
        
        if let apiKey = apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        return try JSONDecoder().decode(CaptureStatus.self, from: data)
    }
    
    // MARK: - Get Result
    func getResult(captureId: String) async throws -> CaptureResult {
        var request = URLRequest(url: URL(string: "\(baseURL)/v1/captures/\(captureId)/result")!)
        request.httpMethod = "GET"
        
        if let apiKey = apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        return try JSONDecoder().decode(CaptureResult.self, from: data)
    }
}

// MARK: - Response Models
struct CreateCaptureResponse: Codable {
    let captureId: String
    let uploadURL: String
    let uploadHeaders: [String: String]?
}

struct CaptureStatus: Codable {
    let state: String // created | queued | processing | done | failed
    let progress: Int // 0..100
    let message: String?
}

struct CaptureResult: Codable {
    let glbURL: String
    let usdzURL: String?
}

enum APIError: Error {
    case requestFailed(statusCode: Int)
    case invalidResponse
    case decodingError
}

