import { useEffect, useState } from 'react';
import { ContentApi } from '../questions/content-api';

type ManifestPreview = { manifestHash: string | null; questionCount: number; animationCount: number;
  canImport: boolean; issues: { path: string; message: string }[] };
type Capabilities = { canPersistBank: boolean; persistenceStatus: string; animationAllowedHosts: string[] };
type Evidence = { sourceUrl: string; retrievedAtUtc: string; htmlSha256: string; contentSha256: string;
  documentNumber: string; title: string; content: string;
  chunks: { sequence: number; article?: string; clause?: string; point?: string; content: string }[] };

export function ContentPreflight({ api }: { api: ContentApi }) {
  const [capabilities, setCapabilities] = useState<Capabilities>();
  const [preview, setPreview] = useState<ManifestPreview>(); const [manifest, setManifest] = useState<unknown>();
  const [source, setSource] = useState(''); const [evidence, setEvidence] = useState<Evidence>();
  const [busy, setBusy] = useState(false); const [error, setError] = useState('');
  useEffect(() => { const controller = new AbortController();
    api<Capabilities>('/api/admin/content-previews/capabilities', { signal: controller.signal }).then(setCapabilities)
      .catch(e => { if (!controller.signal.aborted) setError(e.message); });
    return () => controller.abort();
  }, [api]);
  async function run(action: () => Promise<void>) {
    setBusy(true); setError('');
    try { await action(); } catch(e) { setError(e instanceof Error ? e.message : 'Không kiểm tra được nội dung.'); }
    finally { setBusy(false); }
  }
  async function check(file?: File) {
    if (!file) return;
    setPreview(undefined); setManifest(undefined);
    await run(async () => {
      if (file.size > 10 * 1024 * 1024) throw new Error('Gói JSON phải nhỏ hơn 10 MB.');
      const json: unknown = JSON.parse(await file.text());
      if (!json || typeof json !== 'object' || Array.isArray(json)) throw new Error('Gói import phải là JSON object.');
      const body = 'bank' in json ? json : { bank: json, animations: [] };
      const result = await api<ManifestPreview>('/api/admin/content-previews/question-banks', { method: 'POST', body: JSON.stringify(body) });
      setManifest(body); setPreview(result);
    });
  }
  async function inspectSource() {
    setEvidence(undefined);
    await run(async () => setEvidence(await api<Evidence>('/api/admin/content-previews/legal-source', {
      method: 'POST', body: JSON.stringify({ sourceUrl: source }) })));
  }
  return <section aria-labelledby="preflight-title"><h1 id="preflight-title">Kiểm tra nội dung trước khi nhập</h1>
    <p>Đối chiếu gói câu hỏi, nguồn văn bản và liên kết minh họa.</p>
    {capabilities && !capabilities.canPersistBank && <p role="status">Có thể kiểm tra nội dung. Chức năng lưu và xuất bản đang chờ kho SQL Content/Exam được tích hợp.</p>}
    <article><h2>Ngân hàng câu hỏi và animation</h2>
      <label>Gói JSON<input type="file" accept="application/json,.json" disabled={busy} onChange={e => void check(e.target.files?.[0])}/></label>
      <p>Host animation được cho phép: {capabilities?.animationAllowedHosts.join(', ') || 'chưa cấu hình'}.</p>
      {preview && <><p>{preview.questionCount} câu · {preview.animationCount} animation · {preview.canImport ? 'Đạt kiểm tra cấu trúc' : 'Cần sửa nội dung'}</p>
        {preview.manifestHash && <p>Hash bản kiểm tra: <code>{preview.manifestHash}</code></p>}
        <ul>{preview.issues.map((issue, i) => <li key={i}><code>{issue.path}</code>: {issue.message}</li>)}</ul>
        <details><summary>Xem gói đầy đủ (gồm đáp án, chỉ Admin)</summary><pre>{JSON.stringify(manifest, null, 2)}</pre></details>
        <button disabled title="Chờ schema và repository SQL của module nội dung">Lưu bản nháp vào SQL — chờ tích hợp</button></>}
    </article>
    <article><h2>Nguồn văn bản luật</h2><form onSubmit={e => { e.preventDefault(); void inspectSource(); }}>
      <label>URL Thư viện Pháp luật<input type="url" required value={source} disabled={busy} onChange={e => setSource(e.target.value)}/></label>
      <button disabled={busy}>Đọc và xem trước</button></form>
      {evidence && <><h3>{evidence.title}</h3><p>Số hiệu: {evidence.documentNumber} · {evidence.chunks.length} chunks</p>
        <p>Đọc nguồn lúc {new Date(evidence.retrievedAtUtc).toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' })}</p>
        <p>Hash toàn văn: <code>{evidence.contentSha256}</code></p><p>Hash HTML: <code>{evidence.htmlSha256}</code></p>
        <p>Trạng thái: bản xem trước, chưa xác minh hiệu lực và chưa đưa vào RAG.</p>
        <details><summary>Toàn văn đã tách</summary><pre>{evidence.content}</pre></details>
        <details><summary>Điều / Khoản / Điểm và thứ tự chunks</summary>{evidence.chunks.map(c => <div key={c.sequence}>
          <strong>#{c.sequence + 1} · Điều {c.article ?? '—'} · Khoản {c.clause ?? '—'} · Điểm {c.point ?? '—'}</strong><pre>{c.content}</pre></div>)}</details>
      </>}
    </article>{busy && <p role="status">Đang kiểm tra…</p>}{error && <p role="alert">{error}</p>}
  </section>;
}
