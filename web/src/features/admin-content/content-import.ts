type JsonObject = Record<string, unknown>;

export type BankImportManifest = { bank: JsonObject; animations: unknown[] };
export type ParsedBankFile = { manifest: BankImportManifest; templateCount: number };

function object(value: unknown): value is JsonObject {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

// Accept a raw bank or the reviewed {bank, templates, evidence} package without changing its contents.
// Domain rules and applying animation mappings belong to the server.
export function parseBankFile(text: string): ParsedBankFile {
  let value: unknown;
  try { value = JSON.parse(text); } catch { throw new Error('File không phải JSON hợp lệ.'); }
  if (!object(value)) throw new Error('Gói import phải là JSON object.');
  const envelope = 'bank' in value;
  const bank = envelope ? value.bank : value;
  if (!object(bank)) throw new Error('Thiếu ngân hàng câu hỏi trong gói import.');
  const animations = envelope && 'animations' in value ? value.animations : [];
  if (!Array.isArray(animations)) throw new Error('Danh sách animation phải là mảng JSON.');
  return { manifest: { bank, animations }, templateCount: envelope && Array.isArray(value.templates) ? value.templates.length : 0 };
}

export function reviewedImportBody(manifest: BankImportManifest, manifestHash: string | null) {
  if (!manifestHash || !/^[A-Fa-f0-9]{64}$/.test(manifestHash)) throw new Error('Cần kiểm tra lại gói nội dung trước khi nhập.');
  return { ...manifest, expectedManifestHash: manifestHash };
}
