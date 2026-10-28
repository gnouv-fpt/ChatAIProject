export function validateScenario(value) {
  const errors = [];
  if (!value || typeof value !== 'object' || Array.isArray(value)) return ['Tình huống phải là JSON object.'];
  const guid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (typeof value.questionId !== 'string' || !guid.test(value.questionId)) errors.push('Thiếu questionId GUID hợp lệ.');
  if (typeof value.bankVersion !== 'string' || !/^[A-Za-z0-9._-]{1,64}$/.test(value.bankVersion)) errors.push('Thiếu bankVersion hợp lệ.');
  for (const field of ['title', 'description']) if (typeof value[field] !== 'string' || !value[field].trim() || value[field].length > 2000) errors.push(`${field} cần nội dung tối đa 2000 ký tự.`);
  try { const source = new URL(value.sourceUrl); if (source.protocol !== 'https:' || source.username || source.password) throw new Error(); }
  catch { errors.push('sourceUrl cần URL HTTPS không có thông tin đăng nhập.'); }
  if (!Array.isArray(value.steps) || value.steps.length < 2 || value.steps.length > 30) errors.push('Tình huống cần từ 2 đến 30 bước.');
  else value.steps.forEach((step, i) => {
    if (!step || typeof step !== 'object') { errors.push(`Bước ${i + 1} không hợp lệ.`); return; }
    if (typeof step.caption !== 'string' || !step.caption.trim() || step.caption.length > 2000) errors.push(`Bước ${i + 1} thiếu chú thích.`);
    if (!Number.isFinite(step.x) || step.x < 25 || step.x > 615 || !Number.isFinite(step.y) || step.y < 25 || step.y > 375 ||
      !Number.isFinite(step.rotation) || step.rotation < -360 || step.rotation > 360) errors.push(`Bước ${i + 1} có tọa độ/góc ngoài giới hạn.`);
  });
  return errors;
}
