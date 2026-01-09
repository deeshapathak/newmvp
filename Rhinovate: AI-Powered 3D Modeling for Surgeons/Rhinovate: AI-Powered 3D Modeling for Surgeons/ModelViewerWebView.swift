//
//  ModelViewerWebView.swift
//  Rhinovate Capture
//
//  SwiftUI wrapper for WKWebView displaying model-viewer
//

import SwiftUI
import WebKit

struct ModelViewerWebView: UIViewRepresentable {
    let glbURL: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        
        // Load model-viewer HTML
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/3.3.0/model-viewer.min.js"></script>
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    background: #000;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                }
                model-viewer {
                    width: 100%;
                    height: 100vh;
                    background: #000;
                }
            </style>
        </head>
        <body>
            <model-viewer
                src="\(glbURL)"
                alt="3D Face Model"
                auto-rotate
                camera-controls
                interaction-policy="allow-when-focused"
                style="width: 100%; height: 100vh;">
            </model-viewer>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("ModelViewerWebView: Failed to load - \(error.localizedDescription)")
        }
    }
}

