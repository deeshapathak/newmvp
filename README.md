# Rhinovate Capture

An iOS app MVP that captures 3D face meshes using the TrueDepth camera and exports them as GLB files.

## Features

- **3D Face Capture**: Uses ARKit's face tracking to capture high-quality 3D face meshes
- **Quality Filtering**: Only accepts frames with neutral expressions and minimal head movement
- **3D Preview**: View captured meshes in an interactive 3D viewer with orbit controls
- **GLB Export**: Export meshes as glTF 2.0 binary (GLB) files for use in web viewers and 3D tools
- **Share Integration**: Share exported GLB files using iOS share sheet

## Requirements

- iOS 17.0 or later
- Device with TrueDepth camera (iPhone X or later)
- Xcode 15.0 or later

## Project Structure

```
RhinovateCaptureApp.swift      # App entry point
CaptureView.swift              # Main capture screen UI
PreviewView.swift              # Preview screen with 3D viewer
ARFaceTrackingView.swift       # ARKit face tracking wrapper
FaceCaptureManager.swift       # Capture logic and quality filtering
FaceMesh.swift                 # Mesh data structure
GLBExporter.swift              # glTF 2.0 binary exporter
MathUtils.swift                # Mathematical utilities
ShareSheet.swift               # iOS share sheet wrapper
Info.plist                     # App configuration
```

## How It Works

### Capture Process

1. **Initialization**: The app checks for TrueDepth camera support and initializes ARKit face tracking
2. **Frame Collection**: When "Start Capture" is pressed, the app collects frames for 2 seconds
3. **Quality Filtering**: Each frame is evaluated based on:
   - Tracking state (must be normal)
   - Expression neutrality (jaw, mouth, brow movements below thresholds)
   - Head motion (translation delta between frames must be < 1cm)
4. **Vertex Averaging**: Accepted frames are averaged to produce a stable mesh
5. **Normal Computation**: Per-vertex normals are computed from triangle face normals

### Coordinate System

- **ARKit**: Right-handed, Y-up coordinate system
- **glTF**: Right-handed, Y-up coordinate system
- The mesh is exported as-is without coordinate transformation

### GLB Export

The GLB exporter implements a minimal glTF 2.0 binary writer that supports:
- Single mesh with one primitive
- POSITION attributes (Float32 vec3)
- NORMAL attributes (Float32 vec3)
- INDICES (UInt32)
- Interleaved vertex buffer format
- Proper 4-byte alignment for all buffers

## Setting Up the Xcode Project

1. **Create a new Xcode project**:
   - Open Xcode
   - Choose "Create a new Xcode project"
   - Select "iOS" → "App"
   - Product Name: `RhinovateCapture`
   - Interface: SwiftUI
   - Language: Swift
   - Minimum Deployment: iOS 17.0

2. **Add the source files**:
   - Copy all `.swift` files from this directory into your Xcode project
   - Ensure all files are added to the target

3. **Configure Info.plist**:
   - Replace the default `Info.plist` with the provided one, or add the camera usage description manually:
   - Key: `NSCameraUsageDescription`
   - Value: `Rhinovate Capture needs camera access to capture 3D face meshes using TrueDepth camera.`

4. **Configure capabilities**:
   - In Xcode, select your target
   - Go to "Signing & Capabilities"
   - Ensure "ARKit" capability is enabled (should be automatic)

## Building the Project

1. Connect a device with TrueDepth camera (iPhone X or later)
2. Select the device as your run destination
3. Build and run (⌘R)

## Usage

1. **Capture Screen**:
   - Ensure TrueDepth is supported (status indicator at top)
   - Hold a neutral expression
   - Tap "Start Capture (2s)"
   - Keep head still and maintain neutral expression for 2 seconds
   - Tap "Finish" when ready

2. **Preview Screen**:
   - View your captured 3D mesh
   - Use pan gestures to rotate
   - Use pinch gestures to zoom
   - Tap "Export GLB" to save the file
   - Tap "Share GLB" to share via iOS share sheet
   - Tap "Re-Capture" to start over

## Validating GLB Files

### Online Viewers

1. **glTF Viewer**: https://gltf-viewer.donmccurdy.com/
   - Upload your exported GLB file
   - Verify geometry appears correctly

2. **Three.js Editor**: https://threejs.org/editor/
   - Import the GLB file
   - Check mesh orientation and scale

### Command Line (using gltf-transform)

```bash
npm install -g @gltf-transform/cli
gltf-transform validate rhinovate_face.glb
```

### Expected Results

- Mesh should display with correct geometry
- Face should be oriented correctly (not flipped or rotated)
- Normals should be smooth (no faceted appearance)
- Scale should be in meters (typical face dimensions: ~0.15m width, ~0.2m height)

## Technical Details

### Capture Quality Thresholds

- **Head Motion**: Maximum 1cm translation between frames
- **Expression Thresholds**:
  - `jawOpen`: 0.1
  - `mouthSmileLeft/Right`: 0.3
  - `browInnerUp`: 0.3
- **Minimum Frames**: 20 accepted frames required

### Mesh Processing

- Vertices are averaged across all accepted frames
- Normals are computed after averaging using face normals
- Triangle topology is preserved from ARKit's face geometry
- All data is in meters (ARKit's native unit)

### GLB Structure

```
GLB Header (12 bytes)
├── Magic: 0x46546C67
├── Version: 2
└── Total Length

JSON Chunk
├── Length
├── Type: 0x4E4F534A ("JSON")
└── JSON Data (padded to 4-byte boundary)

BIN Chunk
├── Length
├── Type: 0x004E4942 ("BIN\0")
└── Binary Data (padded to 4-byte boundary)
```

## Troubleshooting

### "TrueDepth not supported"
- Ensure you're running on a device with TrueDepth camera (iPhone X or later)
- Check that camera permissions are granted

### "Insufficient Frames"
- Hold a neutral expression (no smiling, no jaw movement)
- Keep head very still during capture
- Ensure good lighting
- Try again if tracking is limited

### GLB doesn't load in viewer
- Verify file was exported successfully
- Check file size (should be > 0 bytes)
- Try re-exporting the mesh
- Validate using gltf-transform

## License

This is an MVP implementation for demonstration purposes.

