# Build Guide for Rhinovate Capture

## Quick Start

### Step 1: Create New Xcode Project

1. **Open Xcode** (Xcode 15.0 or later required)

2. **Create a new project**:
   - File → New → Project (or ⌘⇧N)
   - Select **"iOS"** tab
   - Choose **"App"** template
   - Click **Next**

3. **Configure project settings**:
   - **Product Name**: `RhinovateCapture` (or your preferred name)
   - **Team**: Select your development team (or "None" for personal use)
   - **Organization Identifier**: e.g., `com.yourname` (required)
   - **Bundle Identifier**: Will auto-generate (e.g., `com.yourname.RhinovateCapture`)
   - **Interface**: **SwiftUI**
   - **Language**: **Swift**
   - **Storage**: **None** (we don't need Core Data)
   - **Include Tests**: Optional (unchecked is fine)
   - Click **Next**
   
   **Note**: If you already created the project as "Rhinovate: AI-Powered 3D Modeling for Surgeons", that's fine! Just use your actual target name in the steps below.

4. **Choose location**:
   - Navigate to `/Users/deeshapathak/newmvp`
   - **IMPORTANT**: Uncheck "Create Git repository" if you don't want one
   - Click **Create**

### Step 2: Replace Default Files

1. **Delete the default ContentView.swift**:
   - In Xcode, right-click `ContentView.swift` in the Project Navigator
   - Select "Delete" → "Move to Trash"

2. **Add all source files**:
   - In Xcode, right-click on your project name in the Project Navigator
   - Select "Add Files to '[Your Project Name]'..."
   - Navigate to `/Users/deeshapathak/newmvp`
   - Select ALL `.swift` files:
     - `RhinovateCaptureApp.swift`
     - `CaptureView.swift`
     - `PreviewView.swift`
     - `ARFaceTrackingView.swift`
     - `FaceCaptureManager.swift`
     - `FaceMesh.swift`
     - `GLBExporter.swift`
     - `MathUtils.swift`
     - `ShareSheet.swift`
   - **IMPORTANT**: Check "Copy items if needed" (unchecked is fine if files are in the same directory)
   - Check "Add to targets: [Your Target Name]" (usually matches your project name)
   - Click **Add**

3. **Update Info.plist**:
   - In Xcode, find `Info.plist` in the Project Navigator
   - Open it and add the camera permission:
     - Right-click in the plist → "Add Row"
     - Key: `Privacy - Camera Usage Description` (or `NSCameraUsageDescription`)
     - Type: `String`
     - Value: `Rhinovate Capture needs camera access to capture 3D face meshes using TrueDepth camera.`
   - **OR** replace the entire `Info.plist` file with the provided one

### Step 3: Configure Project Settings

1. **Set minimum iOS version**:
   - Select your project in the Project Navigator (top item - "Rhinovate: AI-Powered 3D Modeling for Surgeons")
   - Select your **target** (usually has the same name as your project)
   - Go to **"General"** tab
   - Under **"Deployment Info"**, set **iOS** to **17.0** (or higher)

2. **Enable ARKit** (usually automatic, but verify):
   - Still in the target settings
   - Go to **"Signing & Capabilities"** tab
   - If ARKit is not listed, click **"+ Capability"**
   - Add **"ARKit"**

3. **Update App Entry Point**:
   - Open `RhinovateCaptureApp.swift`
   - Ensure it matches the structure (it should already be correct)

### Step 4: Build and Run

1. **Connect your device**:
   - Connect an iPhone with TrueDepth camera (iPhone X or later) via USB
   - Unlock your iPhone
   - Trust the computer if prompted

2. **Select device**:
   - In Xcode toolbar, click the device selector (next to the play button)
   - Select your connected iPhone

3. **Build**:
   - Product → Build (or ⌘B)
   - Wait for build to complete (should show "Build Succeeded")

4. **Run**:
   - Product → Run (or ⌘R)
   - Xcode will install the app on your device
   - **First time**: On your iPhone, go to Settings → General → VPN & Device Management
   - Trust your developer certificate
   - Open the app on your iPhone

## Troubleshooting

### "No such module 'ARKit'" or "No such module 'RealityKit'"
- Ensure you're targeting iOS 17.0 or higher
- Clean build folder: Product → Clean Build Folder (⇧⌘K)
- Build again

### "TrueDepth not supported"
- You must run on a physical device with TrueDepth camera
- Simulator does NOT support TrueDepth
- Required devices: iPhone X, XS, XR, 11, 12, 13, 14, 15, or later

### Build errors about missing files
- Ensure all `.swift` files are added to the target
- Select each file in Project Navigator
- In File Inspector (right panel), check "Target Membership" → "RhinovateCapture" is checked

### Camera permission denied
- Check `Info.plist` has `NSCameraUsageDescription`
- Delete app from device and reinstall
- Go to iPhone Settings → RhinovateCapture → Enable Camera permission

### Code signing errors
- Go to Signing & Capabilities
- Select your Apple ID team
- Or set "Automatically manage signing" to ON

## Alternative: Command Line Build

If you prefer command line:

```bash
# Navigate to project directory
cd /Users/deeshapathak/newmvp

# List available schemes (after creating Xcode project)
xcodebuild -list

# Build for device (replace with your scheme name)
# If your project is named "Rhinovate: AI-Powered 3D Modeling for Surgeons", 
# the scheme name might be different - check with xcodebuild -list
xcodebuild -scheme "Rhinovate: AI-Powered 3D Modeling for Surgeons" -configuration Debug -destination 'platform=iOS,id=YOUR_DEVICE_UDID' build

# Or build for generic iOS device
xcodebuild -scheme "Rhinovate: AI-Powered 3D Modeling for Surgeons" -sdk iphoneos -configuration Debug build
```

## Verification Checklist

- [ ] All 9 Swift files added to project
- [ ] Info.plist has camera permission
- [ ] iOS deployment target is 17.0+
- [ ] ARKit capability is enabled
- [ ] Project builds without errors
- [ ] App runs on TrueDepth-capable device
- [ ] Camera permission prompt appears on first launch

## Next Steps After Building

1. **Test capture**:
   - Open the app
   - Verify "TrueDepth supported" shows green
   - Tap "Start Capture (2s)"
   - Hold neutral expression, keep head still
   - Tap "Finish" after 2 seconds

2. **Test preview**:
   - View your 3D mesh
   - Try panning and pinching to rotate/zoom

3. **Test export**:
   - Tap "Export GLB"
   - Tap "Share GLB"
   - Verify file can be shared/opened

4. **Validate GLB**:
   - Share GLB to a computer
   - Open in https://gltf-viewer.donmccurdy.com/
   - Verify mesh displays correctly

