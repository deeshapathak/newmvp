//
//  KV State Management
//

import { KVNamespace } from '@cloudflare/workers-types';

export interface CaptureState {
  state: 'created' | 'queued' | 'processing' | 'done' | 'failed';
  progress: number; // 0-100
  message?: string;
  uploaded: boolean;
  resultGLBKey?: string;
  resultUSDZKey?: string;
}

export async function getCaptureState(kv: KVNamespace, captureId: string): Promise<CaptureState | null> {
  const value = await kv.get(`capture:${captureId}`);
  if (!value) return null;
  return JSON.parse(value) as CaptureState;
}

export async function setCaptureState(kv: KVNamespace, captureId: string, state: CaptureState): Promise<void> {
  await kv.put(`capture:${captureId}`, JSON.stringify(state));
}

export async function initializeCaptureState(kv: KVNamespace, captureId: string): Promise<void> {
  const initialState: CaptureState = {
    state: 'created',
    progress: 0,
    uploaded: false,
  };
  await setCaptureState(kv, captureId, initialState);
}

