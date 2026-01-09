//
//  ResultView.swift
//  Rhinovate Capture
//
//  Displays cloud-processed result with model-viewer
//

import SwiftUI

struct ResultView: View {
    let captureId: String
    let glbURL: String
    let usdzURL: String?
    
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Model viewer
                ModelViewerWebView(glbURL: glbURL)
                    .edgesIgnoringSafeArea(.all)
                
                // Control panel
                VStack {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Button(action: {
                            showShareSheet = true
                        }) {
                            Text("Share Model")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Done")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Processed Model")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [URL(string: glbURL)!])
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

