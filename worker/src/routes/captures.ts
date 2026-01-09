//
//  Capture API Routes
//

import { Env } from '../index';
import { generatePresignedURL } from '../r2sign';
import { initializeCaptureState, getCaptureState, setCaptureState, CaptureState } from '../state';

export async function createCapture(request: Request, env: Env): Promise<Response> {
  // Check API key if configured
  if (env.API_KEY) {
    const apiKey = request.headers.get('X-API-Key');
    if (apiKey !== env.API_KEY) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      });
    }
  }

  // Generate capture ID
  const captureId = crypto.randomUUID();
  
  // Initialize state
  await initializeCaptureState(env.CAPTURES_KV, captureId);
  
  // Use direct upload endpoint (simpler - Worker handles upload)
  const baseURL = new URL(request.url).origin;
  const uploadURL = `${baseURL}/v1/upload/${captureId}`;
  
  const response = {
    captureId,
    uploadURL,
    uploadHeaders: {
      'Content-Type': 'application/zip',
    },
  };
  
  return new Response(JSON.stringify(response), {
    status: 201,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  });
}

export async function completeUpload(request: Request, env: Env, captureId: string): Promise<Response> {
  // Check API key if configured
  if (env.API_KEY) {
    const apiKey = request.headers.get('X-API-Key');
    if (apiKey !== env.API_KEY) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      });
    }
  }

  // Update state to uploaded and queued
  const state = await getCaptureState(env.CAPTURES_KV, captureId);
  if (!state) {
    return new Response(JSON.stringify({ error: 'Capture not found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  
  state.uploaded = true;
  state.state = 'queued';
  state.progress = 10;
  await setCaptureState(env.CAPTURES_KV, captureId, state);
  
  // Trigger Render worker
  try {
    const renderResponse = await fetch(`${env.RENDER_WORKER_URL}/process`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Worker-Secret': env.WORKER_SECRET,
      },
      body: JSON.stringify({
        captureId,
        objectKey: `captures/${captureId}/capture.zip`,
      }),
    });
    
    if (!renderResponse.ok) {
      console.error('Failed to trigger Render worker:', await renderResponse.text());
      state.state = 'failed';
      state.message = 'Failed to start processing';
      await setCaptureState(env.CAPTURES_KV, captureId, state);
    }
  } catch (error) {
    console.error('Error triggering Render worker:', error);
    state.state = 'failed';
    state.message = 'Failed to start processing';
    await setCaptureState(env.CAPTURES_KV, captureId, state);
  }
  
  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  });
}

export async function getStatus(request: Request, env: Env, captureId: string): Promise<Response> {
  const state = await getCaptureState(env.CAPTURES_KV, captureId);
  
  if (!state) {
    return new Response(JSON.stringify({ error: 'Capture not found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  
  const response = {
    state: state.state,
    progress: state.progress,
    message: state.message,
  };
  
  return new Response(JSON.stringify(response), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  });
}

export async function getResult(request: Request, env: Env, captureId: string): Promise<Response> {
  const state = await getCaptureState(env.CAPTURES_KV, captureId);
  
  if (!state || state.state !== 'done') {
    return new Response(JSON.stringify({ error: 'Result not ready' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  
  // Generate presigned GET URLs
  const glbKey = state.resultGLBKey || `results/${captureId}/result.glb`;
  const glbURL = await generatePresignedURL({
    method: 'GET',
    bucket: env.R2_BUCKET_NAME,
    key: glbKey,
    expiresIn: 3600,
    accessKeyId: env.R2_ACCESS_KEY_ID,
    secretAccessKey: env.R2_SECRET_ACCESS_KEY,
  });
  
  let usdzURL: string | undefined;
  if (state.resultUSDZKey) {
    usdzURL = await generatePresignedURL({
      method: 'GET',
      bucket: env.R2_BUCKET_NAME,
      key: state.resultUSDZKey,
      expiresIn: 3600,
      accessKeyId: env.R2_ACCESS_KEY_ID,
      secretAccessKey: env.R2_SECRET_ACCESS_KEY,
    });
  }
  
  const response = {
    glbURL,
    usdzURL,
  };
  
  return new Response(JSON.stringify(response), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  });
}

