//
//  Texture Generator
//  Generates placeholder texture (skin-like gradient)
//

import { createCanvas } from 'canvas';

export async function generateTexture(width: number, height: number): Promise<Buffer> {
  const canvas = createCanvas(width, height);
  const ctx = canvas.getContext('2d');

  // Create skin-like gradient
  const gradient = ctx.createLinearGradient(0, 0, width, height);
  gradient.addColorStop(0, '#f4c2a1'); // Light skin tone
  gradient.addColorStop(0.5, '#e8a87c'); // Medium skin tone
  gradient.addColorStop(1, '#d4885c'); // Darker skin tone

  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height);

  // Add some subtle noise/texture
  const imageData = ctx.getImageData(0, 0, width, height);
  const data = imageData.data;

  for (let i = 0; i < data.length; i += 4) {
    // Add slight random variation
    const noise = (Math.random() - 0.5) * 10;
    data[i] = Math.max(0, Math.min(255, data[i] + noise)); // R
    data[i + 1] = Math.max(0, Math.min(255, data[i + 1] + noise)); // G
    data[i + 2] = Math.max(0, Math.min(255, data[i + 2] + noise)); // B
  }

  ctx.putImageData(imageData, 0, 0);

  // Convert to PNG buffer
  return canvas.toBuffer('image/png');
}

