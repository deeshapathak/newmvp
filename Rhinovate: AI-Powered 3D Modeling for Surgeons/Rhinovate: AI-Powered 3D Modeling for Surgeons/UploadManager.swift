//
//  UploadManager.swift
//  Rhinovate Capture
//
//  Handles presigned PUT upload to R2 with progress tracking
//

import Foundation

class UploadManager: NSObject {
    private var uploadTask: URLSessionUploadTask?
    private var progressHandler: ((Double) -> Void)?
    private var completionHandler: ((Result<Void, Error>) -> Void)?
    
    func upload(fileURL: URL, to uploadURL: String, headers: [String: String]? = nil, progress: @escaping (Double) -> Void, completion: @escaping (Result<Void, Error>) -> Void) {
        self.progressHandler = progress
        self.completionHandler = completion
        
        guard let url = URL(string: uploadURL) else {
            completion(.failure(UploadError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/zip", forHTTPHeaderField: "Content-Type")
        
        // Add API key if in headers
        headers?.forEach { key, value in
            if key != "Content-Type" { // Don't override Content-Type
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        uploadTask = session.uploadTask(with: request, fromFile: fileURL)
        uploadTask?.resume()
    }
    
    func cancel() {
        uploadTask?.cancel()
    }
}

extension UploadManager: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            completionHandler?(.failure(error))
        } else {
            completionHandler?(.success(()))
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        DispatchQueue.main.async {
            self.progressHandler?(progress)
        }
    }
}

enum UploadError: Error {
    case invalidURL
    case uploadFailed
}

