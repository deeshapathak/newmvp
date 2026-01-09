//
//  R2 Presigned URL Signer (AWS Signature V4 compatible)
//  Uses Web Crypto API for Workers environment
//

export interface PresignedURLParams {
  method: string;
  bucket: string;
  key: string;
  expiresIn: number; // seconds
  accessKeyId: string;
  secretAccessKey: string;
  region?: string;
}

export async function generatePresignedURL(params: PresignedURLParams): Promise<string> {
  const { method, bucket, key, expiresIn, accessKeyId, secretAccessKey, region = 'auto' } = params;
  
  const endpoint = `https://${bucket}.r2.cloudflarestorage.com`;
  const expires = Math.floor(Date.now() / 1000) + expiresIn;
  
  // AWS Signature V4
  const date = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const dateTime = new Date().toISOString().slice(0, 19).replace(/[:-]/g, '').replace('T', 'T');
  
  const canonicalUri = `/${key}`;
  const canonicalQueryString = `X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=${encodeURIComponent(`${accessKeyId}/${date}/${region}/s3/aws4_request`)}&X-Amz-Date=${dateTime}&X-Amz-Expires=${expiresIn}&X-Amz-SignedHeaders=host`;
  
  const canonicalHeaders = `host:${bucket}.r2.cloudflarestorage.com\n`;
  const signedHeaders = 'host';
  
  const canonicalRequest = `${method}\n${canonicalUri}\n${canonicalQueryString}\n${canonicalHeaders}\n${signedHeaders}\n${await sha256('')}`;
  
  const algorithm = 'AWS4-HMAC-SHA256';
  const credentialScope = `${date}/${region}/s3/aws4_request`;
  const stringToSign = `${algorithm}\n${dateTime}\n${credentialScope}\n${await sha256(canonicalRequest)}`;
  
  const signingKey = await getSignatureKey(secretAccessKey, date, region, 's3');
  const signatureBytes = await hmacSha256(signingKey, stringToSign);
  const signature = Array.from(signatureBytes).map(b => b.toString(16).padStart(2, '0')).join('');
  
  const presignedURL = `${endpoint}${canonicalUri}?${canonicalQueryString}&X-Amz-Signature=${signature}`;
  
  return presignedURL;
}

async function sha256(data: string): Promise<string> {
  const encoder = new TextEncoder();
  const dataBuffer = encoder.encode(data);
  const hashBuffer = await crypto.subtle.digest('SHA-256', dataBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

async function hmacSha256(key: Uint8Array, data: string): Promise<Uint8Array> {
  const encoder = new TextEncoder();
  const dataBuffer = encoder.encode(data);
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    key,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const signature = await crypto.subtle.sign('HMAC', cryptoKey, dataBuffer);
  return new Uint8Array(signature);
}

async function getSignatureKey(key: string, dateStamp: string, regionName: string, serviceName: string): Promise<Uint8Array> {
  const encoder = new TextEncoder();
  const kSecret = encoder.encode(`AWS4${key}`);
  const kDate = await hmacSha256(kSecret, dateStamp);
  const kRegion = await hmacSha256(kDate, regionName);
  const kService = await hmacSha256(kRegion, serviceName);
  const kSigning = await hmacSha256(kService, 'aws4_request');
  return kSigning;
}

