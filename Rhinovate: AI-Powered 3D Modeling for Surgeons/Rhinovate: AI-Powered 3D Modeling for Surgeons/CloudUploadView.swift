//
//  CloudUploadView.swift
//  Rhinovate Capture
//
//  Handles cloud upload and processing flow
//

import SwiftUI

struct CloudUploadView: View {
    @EnvironmentObject var captureManager: FaceCaptureManager
    @State private var uploadProgress: Double = 0
    @State private var uploadState: UploadState = .idle
    @State private var captureId: String?
    @State private var errorMessage: String?
    @State private var resultURL: String?
    @State private var showResult = false
    
    private let apiClient = APIClient(
        baseURL: "https://your-worker.workers.dev", // TODO: Configure
        apiKey: nil // TODO: Add if needed
    )
    
    private let uploadManager = UploadManager()
    private var pollingManager: PollingManager {
        PollingManager(apiClient: apiClient)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Cloud Processing")
                .font(.title)
                .padding()
            
            switch uploadState {
            case .idle:
                Button("Upload to Cloud") {
                    startUpload()
                }
                .buttonStyle(.borderedProminent)
                
            case .uploading:
                VStack {
                    ProgressView(value: uploadProgress)
                    Text("Uploading... \(Int(uploadProgress * 100))%")
                }
                
            case .queued:
                VStack {
                    ProgressView()
                    Text("Queued for processing...")
                }
                
            case .processing:
                VStack {
                    ProgressView()
                    Text("Processing...")
                }
                
            case .done:
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 50))
                    Text("Processing Complete!")
                    Button("View Result") {
                        showResult = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                
            case .failed:
                VStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 50))
                    Text("Upload Failed")
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    Button("Retry") {
                        startUpload()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            if let captureId = captureId {
                Button("Copy Capture ID") {
                    UIPasteboard.general.string = captureId
                }
                .font(.caption)
            }
        }
        .padding()
        .sheet(isPresented: $showResult) {
            if let url = resultURL {
                ResultView(captureId: captureId ?? "", glbURL: url, usdzURL: nil)
            }
        }
    }
    
    private func startUpload() {
        Task {
            do {
                // 1. Build capture bundle
                uploadState = .uploading
                uploadProgress = 0.1
                
                let bundleURL = try captureManager.buildCaptureBundle()
                
                // 2. Create capture
                uploadProgress = 0.2
                let createResponse = try await apiClient.createCapture()
                captureId = createResponse.captureId
                
                // 3. Upload bundle
                uploadProgress = 0.3
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    uploadManager.upload(
                        fileURL: bundleURL,
                        to: createResponse.uploadURL,
                        headers: createResponse.uploadHeaders,
                        progress: { progress in
                            uploadProgress = 0.3 + (progress * 0.5) // 30% to 80%
                        },
                        completion: { result in
                            switch result {
                            case .success:
                                continuation.resume()
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                        }
                    )
                }
                
                // 4. Mark complete
                uploadProgress = 0.9
                try await apiClient.completeUpload(captureId: createResponse.captureId)
                
                uploadProgress = 1.0
                uploadState = .queued
                
                // 5. Start polling
                await startPolling(captureId: createResponse.captureId)
                
            } catch {
                uploadState = .failed
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func startPolling(captureId: String) async {
        let manager = PollingManager(apiClient: apiClient)
        manager.startPolling(captureId: captureId)
        
        // Monitor status
        while manager.isPolling {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            if let status = manager.status {
                switch status.state {
                case "queued":
                    uploadState = .queued
                case "processing":
                    uploadState = .processing
                case "done":
                    uploadState = .done
                    // Get result URL
                    if let result = try? await apiClient.getResult(captureId: captureId) {
                        resultURL = result.glbURL
                    }
                    manager.stopPolling()
                case "failed":
                    uploadState = .failed
                    errorMessage = status.message
                    manager.stopPolling()
                default:
                    break
                }
            }
        }
    }
}

enum UploadState {
    case idle
    case uploading
    case queued
    case processing
    case done
    case failed
}

