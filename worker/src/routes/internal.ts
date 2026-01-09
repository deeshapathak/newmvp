//
//  Internal API Routes (protected by secret)
//

import { Env } from '../index';
import { getCaptureState, setCaptureState, CaptureState } from '../state';

export async function updateStatus(request: Request, env: Env, captureId: string): Promise<Response> {
  // Verify secret
  const secret = request.headers.get('X-Worker-Secret');
  if (secret !== env.WORKER_SECRET) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  
  const body = await request.json() as Partial<CaptureState>;
  
  const state = await getCaptureState(env.CAPTURES_KV, captureId);
  if (!state) {
    return new Response(JSON.stringify({ error: 'Capture not found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  
  // Update state
  if (body.state !== undefined) state.state = body.state;
  if (body.progress !== undefined) state.progress = body.progress;
  if (body.message !== undefined) state.message = body.message;
  if (body.resultGLBKey !== undefined) state.resultGLBKey = body.resultGLBKey;
  if (body.resultUSDZKey !== undefined) state.resultUSDZKey = body.resultUSDZKey;
  
  await setCaptureState(env.CAPTURES_KV, captureId, state);
  
  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

