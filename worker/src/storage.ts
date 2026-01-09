//
//  R2 Storage Helpers
//

import { R2Bucket } from '@cloudflare/workers-types';

export async function uploadToR2(
  bucket: R2Bucket,
  key: string,
  data: ArrayBuffer | ReadableStream,
  contentType?: string
): Promise<void> {
  await bucket.put(key, data, {
    httpMetadata: {
      contentType: contentType || 'application/octet-stream',
    },
  });
}

export async function getFromR2(bucket: R2Bucket, key: string): Promise<R2ObjectBody | null> {
  return await bucket.get(key);
}

export async function deleteFromR2(bucket: R2Bucket, key: string): Promise<void> {
  await bucket.delete(key);
}

