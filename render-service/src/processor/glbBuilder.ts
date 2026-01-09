//
//  GLB Builder using gltf-transform
//

import { Document, NodeIO } from '@gltf-transform/core';
import { dedup, flatten } from '@gltf-transform/functions';

interface GLBData {
  vertices: Array<{ x: number; y: number; z: number }>;
  normals: Array<{ x: number; y: number; z: number }>;
  indices: number[];
  uvs: number[][];
  texture: Buffer;
}

export async function buildGLB(data: GLBData): Promise<Buffer> {
  const document = new Document();
  const io = new NodeIO();

  // Create texture
  const texture = document.createTexture('faceTexture');
  texture.setImage(data.texture);
  texture.setMimeType('image/png');

  // Create material with PBR
  const material = document.createMaterial('faceMaterial');
  const pbr = material.getExtension('KHR_materials_pbrMetallicRoughness') || 
              material.createExtension('KHR_materials_pbrMetallicRoughness');
  if (pbr) {
    pbr.setBaseColorTexture(texture);
    pbr.setMetallicFactor(0.0);
    pbr.setRoughnessFactor(0.5);
  }

  // Create mesh
  const mesh = document.createMesh('faceMesh');
  const primitive = document.createPrimitive();

  // Positions
  const positions = new Float32Array(data.vertices.length * 3);
  for (let i = 0; i < data.vertices.length; i++) {
    positions[i * 3] = data.vertices[i].x;
    positions[i * 3 + 1] = data.vertices[i].y;
    positions[i * 3 + 2] = data.vertices[i].z;
  }

  // Normals
  const normals = new Float32Array(data.normals.length * 3);
  for (let i = 0; i < data.normals.length; i++) {
    normals[i * 3] = data.normals[i].x;
    normals[i * 3 + 1] = data.normals[i].y;
    normals[i * 3 + 2] = data.normals[i].z;
  }

  // UVs
  const texCoords = new Float32Array(data.uvs.length * 2);
  for (let i = 0; i < data.uvs.length; i++) {
    texCoords[i * 2] = data.uvs[i][0];
    texCoords[i * 2 + 1] = data.uvs[i][1];
  }

  // Indices
  const indices = new Uint32Array(data.indices);

  // Create accessors
  const positionAccessor = document.createAccessor('positions')
    .setArray(positions)
    .setType('VEC3');
  const normalAccessor = document.createAccessor('normals')
    .setArray(normals)
    .setType('VEC3');
  const texCoordAccessor = document.createAccessor('texcoords')
    .setArray(texCoords)
    .setType('VEC2');
  const indexAccessor = document.createAccessor('indices')
    .setArray(indices);

  // Set attributes
  primitive.setAttribute('POSITION', positionAccessor);
  primitive.setAttribute('NORMAL', normalAccessor);
  primitive.setAttribute('TEXCOORD_0', texCoordAccessor);
  primitive.setIndices(indexAccessor);
  primitive.setMaterial(material);

  mesh.addPrimitive(primitive);

  // Create node and scene
  const node = document.createNode('faceNode').setMesh(mesh);
  const scene = document.createScene('scene').addChild(node);
  document.getRoot().setDefaultScene(scene);

  // Optimize
  await document.transform(
    dedup(),
    flatten()
  );

  // Write GLB
  const glbBuffer = await io.writeBinary(document);
  return Buffer.from(glbBuffer);
}

