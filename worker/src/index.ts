//
//  Cloudflare Worker - Main Entry Point
//  Handles capture API endpoints
//

import { createCapture, completeUpload, getStatus, getResult } from './routes/captures';
import { updateStatus } from './routes/internal';

export interface Env {
  R2_BUCKET: R2Bucket;
  CAPTURES_KV: KVNamespace;
  R2_ACCOUNT_ID: string;
  R2_ACCESS_KEY_ID: string;
  R2_SECRET_ACCESS_KEY: string;
  R2_BUCKET_NAME: string;
  WORKER_SECRET: string; // For internal endpoints
  API_KEY?: string; // Optional API key for auth
  RENDER_WORKER_URL: string; // URL to Render worker service
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, X-API-Key',
    };

    // Handle OPTIONS
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Route handling
    try {
      // Public API routes
      if (path === '/v1/captures' && request.method === 'POST') {
        return await createCapture(request, env);
      }

      if (path.startsWith('/v1/captures/') && path.endsWith('/complete') && request.method === 'POST') {
        const captureId = path.split('/')[3];
        return await completeUpload(request, env, captureId);
      }

      if (path.startsWith('/v1/captures/') && path.endsWith('/status') && request.method === 'GET') {
        const captureId = path.split('/')[3];
        return await getStatus(request, env, captureId);
      }

      if (path.startsWith('/v1/captures/') && path.endsWith('/result') && request.method === 'GET') {
        const captureId = path.split('/')[3];
        return await getResult(request, env, captureId);
      }

      // Internal routes (protected by secret)
      if (path.startsWith('/v1/internal/captures/') && path.endsWith('/status') && request.method === 'POST') {
        const captureId = path.split('/')[4];
        return await updateStatus(request, env, captureId);
      }

      // Direct upload endpoint (simpler than presigned URLs)
      if (path.startsWith('/v1/upload/') && request.method === 'PUT') {
        const captureId = path.split('/')[3];
        const objectKey = `captures/${captureId}/capture.zip`;
        const data = await request.arrayBuffer();
        await env.R2_BUCKET.put(objectKey, data, {
          httpMetadata: { contentType: 'application/zip' },
        });
        return new Response(JSON.stringify({ success: true }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      return new Response('Not Found', { status: 404, headers: corsHeaders });
    } catch (error) {
      console.error('Error:', error);
      return new Response(
        JSON.stringify({ error: 'Internal Server Error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
  },
};

