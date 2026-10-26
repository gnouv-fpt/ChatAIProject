import { useEffect, useState } from 'react';
import { Bank, ContentApi, Preview } from '../questions/content-api';

export function AdminContent({ api }: { api: ContentApi }) {
  const [banks, setBanks] = useState<Bank[]>([]); const [preview, setPreview] = useState<Preview>();
  const [reviewed, setReviewed] = useState(false); const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState(''); const [error, setError] = useState('');
  useEffect(() => { const controller = new AbortController();
    api<Bank[]>('/api/admin/question-banks', { signal: controller.signal }).then(setBanks)
      .catch(e => { if (!controller.signal.aborted) setError(e.message); }); return () => controller.abort(); }, [api]);
  async function run(action: () => Promise<void>) {
    setBusy(true); setError(''); setMessage('');
    try { await action(); } catch (e) { setError(e instanceof Error ? e.message : 'Yêu cầu thất bại.'); } finally { setBusy(false); }
  }
  async function importFile(file?: File) {
    if (!file) return;
    await run(async () => {
      if (file.size > 10 * 1024 * 1024) throw new Error('Gói JSON phải nhỏ hơn 10 MB.');
      const bank = JSON.parse(await file.text());
      setPreview(await api<Preview>('/api/admin/question-banks/import', { method: 'POST', body: JSON.stringify({ bank }) }));
      setReviewed(false); setBanks(await api<Bank[]>('/api/admin/question-banks'));
    });
  }
  async function show(bank: Bank) { await run(async () => {
    setPreview(await api<Preview>(`/api/admin/question-banks/${bank.id}/versions/${encodeURIComponent(bank.version)}/preview`)); setReviewed(false);
  }); }
  async function publish() { if (!preview) return; await run(async () => {
    const b = preview.summary;
    const summary = await api<Bank>(`/api/admin/question-banks/${b.id}/versions/${encodeURIComponent(b.version)}/publish`, {
      method: 'POST', body: JSON.stringify({ expectedHash: b.hash, sourceAndAnswersReviewed: reviewed }) });
    setPreview({ ...preview, summary }); setBanks(await api<Bank[]>('/api/admin/question-banks')); setMessage('Đã xuất bản phiên bản bất biến.');
  }); }
  return <section><h1>Quản lý nội dung</h1><p>Import gói JSON, kiểm tra nguồn, đáp án và ảnh trước khi xuất bản.</p>
    <label>Import ngân hàng<input type="file" accept="application/json,.json" disabled={busy} onChange={e => void importFile(e.target.files?.[0])}/></label>
    {busy && <p role="status">Đang xử lý…</p>}{error && <p role="alert">{error}</p>}{message && <p role="status">{message}</p>}
    <ul>{banks.map(b => <li key={`${b.id}/${b.version}`}><button disabled={busy} onClick={() => void show(b)}>{b.title} · {b.version} · {b.isPublished ? 'Đã xuất bản' : 'Bản nháp'}</button></li>)}</ul>
    {preview && <article><h2>Xem trước: {preview.summary.title}</h2><p>SHA-256: <code>{preview.summary.hash}</code></p>
      {preview.errors.map(e => <p role="alert" key={e}>{e}</p>)}<pre>{JSON.stringify(preview.bank, null, 2)}</pre>
      <label><input type="checkbox" checked={reviewed} disabled={busy || preview.summary.isPublished} onChange={e => setReviewed(e.target.checked)}/>
        Tôi đã đối chiếu nguồn, đáp án, profile và nội dung/hash ảnh.</label>
      <button disabled={busy || !reviewed || preview.errors.length > 0 || preview.summary.isPublished} onClick={() => void publish()}>Xuất bản phiên bản này</button></article>}
  </section>;
}
