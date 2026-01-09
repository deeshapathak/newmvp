# Rhinovate Cloud Processing Pipeline

End-to-end cloud-based face capture processing system.

## Architecture

- **iOS App**: Captures face mesh + RGB frames → builds `capture.zip` → uploads to cloud
- **Cloudflare Worker**: API gateway, presigned URLs, job state management
- **Render Service**: Background processor that downloads, processes, and generates GLB
- **R2 Storage**: S3-compatible storage for uploads and results
- **KV Store**: Job state tracking

## Setup

### 1. Cloudflare Worker Setup

1. Install Wrangler CLI:
```bash
npm install -g wrangler
wrangler login
```

2. Create R2 bucket:
```bash
wrangler r2 bucket create rhinovate-captures
```

3. Create KV namespace:
```bash
wrangler kv:namespace create CAPTURES_KV
wrangler kv:namespace create CAPTURES_KV --preview
```

4. Update `worker/wrangler.toml` with your KV namespace IDs.

5. Set secrets:
```bash
wrangler secret put R2_ACCOUNT_ID
wrangler secret put R2_ACCESS_KEY_ID
wrangler secret put R2_SECRET_ACCESS_KEY
wrangler secret put R2_BUCKET_NAME
wrangler secret put WORKER_SECRET
wrangler secret put RENDER_WORKER_URL
wrangler secret put API_KEY  # Optional
```

6. Deploy:
```bash
cd worker
npm install
wrangler deploy
```

### 2. Render Service Setup

1. Create a new Web Service on Render.com

2. Set environment variables:
- `PORT`: 3000
- `R2_ACCOUNT_ID`: Your R2 account ID
- `R2_ACCESS_KEY_ID`: R2 access key
- `R2_SECRET_ACCESS_KEY`: R2 secret key
- `R2_BUCKET_NAME`: rhinovate-captures
- `WORKER_API_URL`: Your Cloudflare Worker URL
- `WORKER_SECRET`: Same secret as Worker

3. Build command:
```bash
npm install && npm run build
```

4. Start command:
```bash
npm start
```

### 3. iOS App Configuration

Update `APIClient` initialization in your app:

```swift
let apiClient = APIClient(
    baseURL: "https://your-worker.workers.dev",
    apiKey: "your-api-key" // Optional
)
```

### 4. Web Viewer

Serve `web/index.html` from any static host, or open directly in browser.

To test with a GLB URL:
```
web/index.html?url=https://your-presigned-glb-url
```

## API Endpoints

### POST /v1/captures
Creates a new capture and returns presigned upload URL.

**Response:**
```json
{
  "captureId": "uuid",
  "uploadURL": "https://presigned-r2-url",
  "uploadHeaders": {
    "Content-Type": "application/zip"
  }
}
```

### POST /v1/captures/:id/complete
Marks upload complete and triggers processing.

### GET /v1/captures/:id/status
Returns current processing status.

**Response:**
```json
{
  "state": "processing",
  "progress": 50,
  "message": "Generating texture"
}
```

### GET /v1/captures/:id/result
Returns presigned URLs for result files.

**Response:**
```json
{
  "glbURL": "https://presigned-glb-url",
  "usdzURL": "https://presigned-usdz-url" // Optional
}
```

## Bundle Format

`capture.zip` contains:
- `manifest.json`: Device info, coordinate system, face transform
- `mesh.json`: Vertices, indices, normals
- `frames/`: Directory with JPEG frames
  - `0001.jpg`, `0002.jpg`, ...
  - `frames.jsonl`: One JSON line per frame with metadata

## Coordinate Conventions

- **System**: Right-handed, Y-up
- **Units**: Meters
- **Face Transform**: 4x4 matrix in world coordinates
- **Camera Intrinsics**: fx, fy, cx, cy in pixels

## Development

### Local Worker Testing
```bash
cd worker
wrangler dev
```

### Local Render Service Testing
```bash
cd render-service
npm run dev
```

## Troubleshooting

1. **Upload fails**: Check R2 credentials and bucket name
2. **Processing stuck**: Check Render service logs and Worker status endpoint
3. **GLB not loading**: Verify CORS on R2 bucket, check presigned URL expiration
4. **Texture missing**: Ensure texture generation in processor is working

## Next Steps

- Replace placeholder texture with multi-frame texture baking
- Add USDZ conversion for iOS QuickLook
- Implement retry logic for failed jobs
- Add job history and querying (migrate to D1 if needed)

