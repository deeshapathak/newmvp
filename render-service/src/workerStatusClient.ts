//
//  Worker Status Client
//  Updates status in Cloudflare Worker via internal API
//

const WORKER_API_URL = process.env.WORKER_API_URL || '';
const WORKER_SECRET = process.env.WORKER_SECRET || '';

export interface StatusUpdate {
  state?: 'created' | 'queued' | 'processing' | 'done' | 'failed';
  progress?: number;
  message?: string;
  resultGLBKey?: string;
  resultUSDZKey?: string;
}

export async function updateWorkerStatus(captureId: string, update: StatusUpdate): Promise<void> {
  try {
    const response = await fetch(`${WORKER_API_URL}/v1/internal/captures/${captureId}/status`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Worker-Secret': WORKER_SECRET,
      },
      body: JSON.stringify(update),
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`Failed to update status: ${response.status} ${text}`);
    }
  } catch (error) {
    console.error(`Error updating worker status for ${captureId}:`, error);
    throw error;
  }
}

