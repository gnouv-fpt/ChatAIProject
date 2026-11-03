// Ground axes calibrated against the two road directions in the 496×280 source.
export const ground = { xx: 24, xz: -22, yx: 5, yz: 16, height: 24, cx: 248, cy: 140 };
export function screenToGround(x, y) {
  const dx = x - ground.cx, dy = y - ground.cy;
  const det = ground.xx * ground.yz - ground.xz * ground.yx;
  return { x: (ground.yz * dx - ground.xz * dy) / det, z: (-ground.yx * dx + ground.xx * dy) / det };
}
export function groundToScreen(x, z, height = 0) {
  return { x: ground.cx + ground.xx * x + ground.xz * z, y: ground.cy + ground.yx * x + ground.yz * z - ground.height * height };
}
