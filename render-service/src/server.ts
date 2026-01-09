//
//  Render Service - Main Server
//  Processes capture bundles and generates GLB files
//

import express from 'express';
import { processCapture } from './processor/faceModelProcessor';
import { updateWorkerStatus } from './workerStatusClient';

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;
const WORKER_SECRET = process.env.WORKER_SECRET || '';
const WORKER_API_URL = process.env.WORKER_API_URL || '';

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Process capture endpoint
app.post('/process', async (req, res) => {
  // Verify secret
  const secret = req.headers['x-worker-secret'];
  if (secret !== WORKER_SECRET) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const { captureId, objectKey } = req.body;

  if (!captureId || !objectKey) {
    return res.status(400).json({ error: 'Missing captureId or objectKey' });
  }

  // Start processing asynchronously
  processCapture(captureId, objectKey).catch((error) => {
    console.error(`Error processing capture ${captureId}:`, error);
    updateWorkerStatus(captureId, {
      state: 'failed',
      progress: 0,
      message: error.message || 'Processing failed',
    }).catch(console.error);
  });

  // Return immediately
  res.json({ success: true, message: 'Processing started' });
});

app.listen(PORT, () => {
  console.log(`Render service listening on port ${PORT}`);
});

