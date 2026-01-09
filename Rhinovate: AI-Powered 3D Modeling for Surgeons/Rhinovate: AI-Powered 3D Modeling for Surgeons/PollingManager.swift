//
//  PollingManager.swift
//  Rhinovate Capture
//
//  Polls capture status until completion
//

import Foundation
import Combine

class PollingManager: ObservableObject {
    @Published var status: CaptureStatus?
    @Published var isPolling: Bool = false
    @Published var error: Error?
    
    private let apiClient: APIClient
    private var pollingTask: Task<Void, Never>?
    private let pollInterval: TimeInterval = 2.0
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    func startPolling(captureId: String) {
        guard !isPolling else { return }
        
        isPolling = true
        error = nil
        
        pollingTask = Task {
            while !Task.isCancelled {
                do {
                    let currentStatus = try await apiClient.getStatus(captureId: captureId)
                    
                    await MainActor.run {
                        self.status = currentStatus
                    }
                    
                    // Stop polling if done or failed
                    if currentStatus.state == "done" || currentStatus.state == "failed" {
                        await MainActor.run {
                            self.isPolling = false
                        }
                        break
                    }
                    
                    // Wait before next poll
                    try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                } catch {
                    await MainActor.run {
                        self.error = error
                        self.isPolling = false
                    }
                    break
                }
            }
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
    }
}

