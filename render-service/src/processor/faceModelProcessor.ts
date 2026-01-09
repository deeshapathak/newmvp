//
//  Face Model Processor
//  Downloads capture.zip, processes it, and generates GLB
//

import * as fs from 'fs';
import * as path from 'path';
import * as zlib from 'zlib';
import { promisify } from 'util';
import { exec } from 'child_process';
import { downloadFromR2, uploadToR2 } from '../r2';
import { generateTexture } from './textureGen';
import { generateUVs } from './uvGen';
import { buildGLB } from './glbBuilder';
import { updateWorkerStatus } from '../workerStatusClient';

const execAsync = promisify(exec);

export async function processCapture(captureId: string, objectKey: string): Promise<void> {
  const tempDir = path.join('/tmp', `capture-${captureId}`);
  
  try {
    // Update status: processing
    await updateWorkerStatus(captureId, {
      state: 'processing',
      progress: 10,
      message: 'Downloading capture bundle',
    });

    // 1. Download capture.zip from R2
    const zipBuffer = await downloadFromR2(objectKey);
    fs.mkdirSync(tempDir, { recursive: true });
    const zipPath = path.join(tempDir, 'capture.zip');
    fs.writeFileSync(zipPath, zipBuffer);

    await updateWorkerStatus(captureId, {
      state: 'processing',
      progress: 20,
      message: 'Extracting bundle',
    });

    // 2. Extract zip
    await execAsync(`unzip -q "${zipPath}" -d "${tempDir}"`);
    const extractDir = tempDir;

    // 3. Parse manifest and mesh
    const manifestPath = path.join(extractDir, 'manifest.json');
    const meshPath = path.join(extractDir, 'mesh.json');
    
    if (!fs.existsSync(manifestPath) || !fs.existsSync(meshPath)) {
      throw new Error('Missing manifest.json or mesh.json');
    }

    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
    const meshData = JSON.parse(fs.readFileSync(meshPath, 'utf-8'));

    await updateWorkerStatus(captureId, {
      state: 'processing',
      progress: 40,
      message: 'Generating texture',
    });

    // 4. Generate placeholder texture
    const textureBuffer = await generateTexture(1024, 1024);

    await updateWorkerStatus(captureId, {
      state: 'processing',
      progress: 60,
      message: 'Generating UVs',
    });

    // 5. Generate UVs
    const vertices = meshData.vertices.map((v: any) => [v.x, v.y, v.z]);
    const uvs = generateUVs(vertices);

    await updateWorkerStatus(captureId, {
      state: 'processing',
      progress: 80,
      message: 'Building GLB',
    });

    // 6. Build GLB
    const glbBuffer = await buildGLB({
      vertices: meshData.vertices,
      normals: meshData.normals || [],
      indices: meshData.indices,
      uvs,
      texture: textureBuffer,
    });

    await updateWorkerStatus(captureId, {
      state: 'processing',
      progress: 90,
      message: 'Uploading result',
    });

    // 7. Upload GLB to R2
    const glbKey = `results/${captureId}/result.glb`;
    await uploadToR2(glbKey, glbBuffer, 'model/gltf-binary');

    // 8. Mark as done
    await updateWorkerStatus(captureId, {
      state: 'done',
      progress: 100,
      message: 'Processing complete',
      resultGLBKey: glbKey,
    });

  } catch (error) {
    console.error(`Error processing capture ${captureId}:`, error);
    await updateWorkerStatus(captureId, {
      state: 'failed',
      progress: 0,
      message: error instanceof Error ? error.message : 'Unknown error',
    });
    throw error;
  } finally {
    // Cleanup
    if (fs.existsSync(tempDir)) {
      fs.rmSync(tempDir, { recursive: true, force: true });
    }
  }
}

