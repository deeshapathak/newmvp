//
//  UV Generator
//  Generates UV coordinates by projecting face-local coordinates
//

export function generateUVs(vertices: number[][]): number[][] {
  if (vertices.length === 0) return [];

  // Find bounding box
  let minX = Infinity, maxX = -Infinity;
  let minY = Infinity, maxY = -Infinity;

  for (const vertex of vertices) {
    minX = Math.min(minX, vertex[0]);
    maxX = Math.max(maxX, vertex[0]);
    minY = Math.min(minY, vertex[1]);
    maxY = Math.max(maxY, vertex[1]);
  }

  const sizeX = maxX - minX;
  const sizeY = maxY - minY;

  // Add 10% padding
  const padding = 0.1;
  const scaleX = (1.0 - 2 * padding) / sizeX;
  const scaleY = (1.0 - 2 * padding) / sizeY;
  const uniformScale = Math.min(scaleX, scaleY);

  const centerX = (minX + maxX) * 0.5;
  const centerY = (minY + maxY) * 0.5;

  // Generate UVs
  const uvs: number[][] = [];
  for (const vertex of vertices) {
    const u = ((vertex[0] - centerX) * uniformScale + 1.0) * 0.5;
    const v = ((vertex[1] - centerY) * uniformScale + 1.0) * 0.5;
    uvs.push([Math.max(0, Math.min(1, u)), Math.max(0, Math.min(1, v))]);
  }

  return uvs;
}

