//
//  PreviewView.swift
//  Rhinovate Capture
//
//  Preview screen displaying captured 3D mesh with export options
//

import SwiftUI
import RealityKit
import ARKit

struct PreviewView: View {
    @EnvironmentObject var captureManager: FaceCaptureManager
    @State private var showShareSheet = false
    @State private var showExportSuccess = false
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
    @State private var exportedFileURL: URL?
    
    var body: some View {
        ZStack {
            // 3D Mesh Viewer
            if let mesh = captureManager.capturedMesh {
                MeshView3D(mesh: mesh)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color.black
                    .edgesIgnoringSafeArea(.all)
            }
            
            // Control Panel
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    // Export GLB Button
                    Button(action: {
                        exportGLB()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Export GLB")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    // Share GLB Button
                    Button(action: {
                        if let url = exportedFileURL ?? getExportedFileURL() {
                            showShareSheet = true
                        } else {
                            exportErrorMessage = "Please export GLB first"
                            showExportError = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share GLB")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(exportedFileURL != nil ? Color.green : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(exportedFileURL == nil)
                    
                    // Re-Capture Button
                    Button(action: {
                        captureManager.reset()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Re-Capture")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedFileURL ?? getExportedFileURL() {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("GLB file exported successfully!")
        }
        .alert("Export Error", isPresented: $showExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportErrorMessage)
        }
    }
    
    private func exportGLB() {
        guard let mesh = captureManager.capturedMesh else {
            exportErrorMessage = "No mesh to export"
            showExportError = true
            return
        }
        
        do {
            let exporter = GLBExporter()
            let url = try exporter.export(mesh: mesh, filename: "rhinovate_face.glb")
            exportedFileURL = url
            showExportSuccess = true
        } catch {
            exportErrorMessage = error.localizedDescription
            showExportError = true
        }
    }
    
    private func getExportedFileURL() -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("rhinovate_face.glb")
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
}

// MARK: - 3D Mesh Viewer
struct MeshView3D: UIViewRepresentable {
    let mesh: FaceMesh
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.backgroundColor = .black
        
        // Create mesh resource
        guard let meshResource = createMeshResource(from: mesh) else {
            return arView
        }
        
        // Create material
        let material = SimpleMaterial(color: .lightGray, isMetallic: false)
        
        // Create model entity
        let modelEntity = ModelEntity(mesh: meshResource, materials: [material])
        
        // Create anchor and add to scene
        let anchor = AnchorEntity(world: [0, 0, -0.5]) // 50cm in front
        anchor.addChild(modelEntity)
        arView.scene.addAnchor(anchor)
        
        // Set up camera
        let camera = PerspectiveCamera()
        camera.position = [0, 0, 0.5]
        let cameraAnchor = AnchorEntity(world: [0, 0, 0])
        cameraAnchor.addChild(camera)
        arView.scene.addAnchor(cameraAnchor)
        
        // Add gesture recognizers for orbit control
        context.coordinator.setupGestures(for: arView, anchor: anchor)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func createMeshResource(from mesh: FaceMesh) -> MeshResource? {
        // Convert to MeshDescriptor format
        var meshDescriptor = MeshDescriptor()
        
        // Positions
        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(mesh.vertices.count)
        for vertex in mesh.vertices {
            // ARKit uses right-handed Y-up, RealityKit uses right-handed Y-up
            // But we may need to adjust coordinate system for glTF compatibility
            // For now, use as-is
            positions.append(vertex)
        }
        meshDescriptor.positions = MeshBuffers.Positions(positions)
        
        // Normals
        var normals: [SIMD3<Float>] = []
        normals.reserveCapacity(mesh.normals.count)
        for normal in mesh.normals {
            normals.append(normal)
        }
        meshDescriptor.normals = MeshBuffers.Normals(normals)
        
        // Indices
        let indices = mesh.indices
        meshDescriptor.primitives = .triangles(indices)
        
        return try? MeshResource.generate(from: [meshDescriptor])
    }
    
    class Coordinator {
        private var lastPanLocation: CGPoint = .zero
        private var rotation: Float = 0
        private var pitch: Float = 0
        private var baseScale: Float = 1.0
        private weak var meshAnchor: AnchorEntity?
        private var panGesture: UIPanGestureRecognizer?
        private var pinchGesture: UIPinchGestureRecognizer?
        
        func setupGestures(for arView: ARView, anchor: AnchorEntity) {
            meshAnchor = anchor
            
            // Pan gesture for rotation
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            arView.addGestureRecognizer(pan)
            panGesture = pan
            
            // Pinch gesture for zoom
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            arView.addGestureRecognizer(pinch)
            pinchGesture = pinch
        }
        
        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let anchor = meshAnchor else { return }
            
            let location = gesture.location(in: gesture.view)
            
            switch gesture.state {
            case .began:
                lastPanLocation = location
            case .changed:
                let deltaX = Float(location.x - lastPanLocation.x) * 0.01
                let deltaY = Float(location.y - lastPanLocation.y) * 0.01
                
                rotation += deltaX
                pitch += deltaY
                pitch = max(-Float.pi / 2, min(Float.pi / 2, pitch))
                
                // Update anchor rotation
                let rotationX = simd_quatf(angle: pitch, axis: [1, 0, 0])
                let rotationY = simd_quatf(angle: rotation, axis: [0, 1, 0])
                anchor.orientation = rotationY * rotationX
                
                lastPanLocation = location
            default:
                break
            }
        }
        
        @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let anchor = meshAnchor else { return }
            
            switch gesture.state {
            case .began:
                baseScale = anchor.scale.x
            case .changed:
                let scale = baseScale * Float(gesture.scale)
                anchor.scale = [scale, scale, scale]
            default:
                break
            }
        }
    }
}

