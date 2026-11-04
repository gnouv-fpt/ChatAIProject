import { useEffect, useState } from 'react';
import { AlertTriangle, CheckCircle2, FileCode2, Globe, LoaderCircle, Save } from 'lucide-react';
import { type ContentApi } from '../questions/content-api';

type ManifestPreview = {
  manifestHash: string | null;
  questionCount: number;
  animationCount: number;
  canImport: boolean;
  issues: { path: string; message: string }[];
};

type Capabilities = {
  canPersistBank: boolean;
  persistenceStatus: string;
  animationAllowedHosts: string[];
};

type Evidence = {
  sourceUrl: string;
  retrievedAtUtc: string;
  htmlSha256: string;
  contentSha256: string;
  documentNumber: string;
  title: string;
  content: string;
  chunks: { sequence: number; article?: string; clause?: string; point?: string; content: string }[];
};

export function ContentPreflight({ api }: { api: ContentApi }) {
  const [capabilities, setCapabilities] = useState<Capabilities>();
  const [preview, setPreview] = useState<ManifestPreview>();
  const [manifest, setManifest] = useState<unknown>();
  const [source, setSource] = useState('');
  const [evidence, setEvidence] = useState<Evidence>();
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    const controller = new AbortController();
    api<Capabilities>('/api/admin/content-previews/capabilities', { signal: controller.signal })
      .then(setCapabilities)
      .catch(e => {
        if (!controller.signal.aborted) setError(e.message);
      });
    return () => controller.abort();
  }, [api]);

  async function run(action: () => Promise<void>) {
    setBusy(true);
    setError('');
    try {
      await action();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Không kiểm tra được nội dung.');
    } finally {
      setBusy(false);
    }
  }

  async function check(file?: File) {
    if (!file) return;
    setPreview(undefined);
    setManifest(undefined);
    setSaved(false);
    await run(async () => {
      if (file.size > 10 * 1024 * 1024) throw new Error('Gói JSON phải nhỏ hơn 10 MB.');
      const json: unknown = JSON.parse(await file.text());
      if (!json || typeof json !== 'object' || Array.isArray(json)) throw new Error('Gói import phải là JSON object.');
      const body = 'bank' in json ? json : { bank: json, animations: [] };
      const result = await api<ManifestPreview>('/api/admin/content-previews/question-banks', {
        method: 'POST',
        body: JSON.stringify(body),
      });
      setManifest(body);
      setPreview(result);
    });
  }

  async function inspectSource() {
    setEvidence(undefined);
    await run(async () =>
      setEvidence(
        await api<Evidence>('/api/admin/content-previews/legal-source', {
          method: 'POST',
          body: JSON.stringify({ sourceUrl: source }),
        })
      )
    );
  }

  return (
    <section aria-labelledby="preflight-title">
      <h2 id="preflight-title" style={{ fontSize: '20px', marginBottom: '6px' }}>
        Kiểm tra nội dung & Nguồn trước khi nhập (Preflight)
      </h2>
      <p className="muted" style={{ marginTop: 0 }}>
        Công cụ tiền kiểm gói manifest (câu hỏi + liên kết mô phỏng 3D) và bóc tách văn bản từ Thư viện Pháp luật.
      </p>

      {capabilities && !capabilities.canPersistBank && (
        <p role="status" className="alert-warning">
          Có thể kiểm tra nội dung. Chức năng lưu và xuất bản đang chờ kho SQL Content/Exam được tích hợp.
        </p>
      )}

      <article>
        <h3 style={{ fontSize: '16px', margin: '0 0 8px' }}>Tiền kiểm gói câu hỏi và liên kết mô phỏng (Animation)</h3>
        <label>
          Gói JSON
          <input
            type="file"
            accept="application/json,.json"
            disabled={busy}
            onChange={e => void check(e.target.files?.[0])}
          />
        </label>
        <p className="muted" style={{ margin: '6px 0 12px' }}>
          Host animation được cho phép: <strong>{capabilities?.animationAllowedHosts.join(', ') || 'chưa cấu hình'}</strong>.
        </p>

        {preview && (
          <>
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))',
                gap: '12px',
                margin: '14px 0',
              }}
            >
              <div className="usage-stat">
                <span>Số câu hỏi</span>
                <strong>{preview.questionCount} câu</strong>
              </div>
              <div className="usage-stat">
                <span>Số mô phỏng</span>
                <strong>{preview.animationCount} animation</strong>
              </div>
              <div className="usage-stat">
                <span>Kết quả tiền kiểm</span>
                <strong style={{ color: preview.canImport ? 'var(--success)' : 'var(--danger)' }}>
                  {preview.canImport ? 'Đạt kiểm tra cấu trúc' : 'Cần sửa nội dung'}
                </strong>
              </div>
            </div>

            {preview.manifestHash && (
              <p style={{ fontSize: '13px' }}>
                Hash bản kiểm tra: <code>{preview.manifestHash}</code>
              </p>
            )}

            {preview.issues.length > 0 && (
              <div className="error" role="alert">
                <strong style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '6px' }}>
                  <AlertTriangle size={16} /> Danh sách lỗi/cảnh báo ({preview.issues.length}):
                </strong>
                <ul style={{ margin: 0, paddingLeft: '18px' }}>
                  {preview.issues.map((issue, i) => (
                    <li key={i}>
                      <code>{issue.path}</code>: {issue.message}
                    </li>
                  ))}
                </ul>
              </div>
            )}

            {preview.canImport && preview.issues.length === 0 && (
              <div className="alert-success">
                <CheckCircle2 size={16} style={{ verticalAlign: '-3px', marginRight: '6px' }} />
                Gói dữ liệu hợp lệ, sẵn sàng lưu thành bản nháp để chuyển sang bước Xuất bản.
              </div>
            )}

            <details style={{ margin: '12px 0' }}>
              <summary style={{ cursor: 'pointer', fontWeight: 600, fontSize: '13.5px', color: 'var(--primary)' }}>
                <FileCode2 size={15} style={{ verticalAlign: '-3px', marginRight: '5px' }} />
                Xem gói đầy đủ (gồm đáp án, chỉ Admin)
              </summary>
              <pre style={{ marginTop: '8px', maxHeight: '320px', overflow: 'auto' }}>
                {JSON.stringify(manifest, null, 2)}
              </pre>
            </details>

            <button
              type="button"
              className="btn-primary"
              disabled={busy || saved || !preview.canImport || !capabilities?.canPersistBank}
              onClick={() =>
                void run(async () => {
                  const body = manifest as {
                    bank: { questions: { id: string }[] };
                    animations: { questionId: string; explanationAnimationUrl: string }[];
                  };
                  const bank = {
                    ...body.bank,
                    questions: body.bank.questions.map(q => {
                      const animation = body.animations.find(a => a.questionId === q.id);
                      return animation ? { ...q, explanationAnimationUrl: animation.explanationAnimationUrl } : q;
                    }),
                  };
                  await api('/api/admin/question-banks/import', {
                    method: 'POST',
                    body: JSON.stringify({ bank }),
                  });
                  setSaved(true);
                })
              }
            >
              <Save size={15} /> {saved ? 'Đã lưu bản nháp' : 'Lưu bản nháp'}
            </button>
          </>
        )}
      </article>

      <article>
        <h3 style={{ fontSize: '16px', margin: '0 0 8px', display: 'flex', alignItems: 'center', gap: '8px' }}>
          <Globe size={17} color="var(--primary)" /> Kiểm tra nguồn văn bản luật
        </h3>
        <form
          onSubmit={e => {
            e.preventDefault();
            void inspectSource();
          }}
          style={{ display: 'flex', flexWrap: 'wrap', gap: '10px', alignItems: 'flex-end' }}
        >
          <label style={{ flex: 1, minWidth: '240px', margin: 0 }}>
            URL Thư viện Pháp luật
            <input
              type="url"
              required
              placeholder="https://thuvienphapluat.vn/van-ban/..."
              value={source}
              disabled={busy}
              onChange={e => setSource(e.target.value)}
            />
          </label>
          <button className="btn-secondary" disabled={busy}>
            Đọc và xem trước
          </button>
        </form>

        {evidence && (
          <div style={{ marginTop: '16px', paddingTop: '14px', borderTop: '1px solid var(--border-light)' }}>
            <h4 style={{ margin: '0 0 6px', fontSize: '16px' }}>{evidence.title}</h4>
            <p style={{ margin: '4px 0', fontSize: '13.5px' }}>
              Số hiệu: <strong>{evidence.documentNumber}</strong> · <strong>{evidence.chunks.length}</strong> chunks
            </p>
            <p className="muted" style={{ margin: '4px 0' }}>
              Đọc nguồn lúc{' '}
              {new Date(evidence.retrievedAtUtc).toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' })}
            </p>
            <p style={{ fontSize: '12.5px', margin: '4px 0' }}>
              Hash toàn văn: <code>{evidence.contentSha256}</code> · Hash HTML: <code>{evidence.htmlSha256}</code>
            </p>
            <p className="alert-info" style={{ margin: '10px 0' }}>
              Trạng thái: bản xem trước, chưa xác minh hiệu lực và chưa đưa vào RAG.
            </p>
            <details style={{ margin: '8px 0' }}>
              <summary style={{ cursor: 'pointer', fontWeight: 600, fontSize: '13.5px', color: 'var(--primary)' }}>
                Toàn văn đã tách
              </summary>
              <pre>{evidence.content}</pre>
            </details>
            <details style={{ margin: '8px 0' }}>
              <summary style={{ cursor: 'pointer', fontWeight: 600, fontSize: '13.5px', color: 'var(--primary)' }}>
                Điều / Khoản / Điểm và thứ tự chunks ({evidence.chunks.length})
              </summary>
              {evidence.chunks.map(c => (
                <div key={c.sequence} style={{ marginTop: '10px' }}>
                  <strong>
                    #{c.sequence + 1} · Điều {c.article ?? '—'} · Khoản {c.clause ?? '—'} · Điểm {c.point ?? '—'}
                  </strong>
                  <pre>{c.content}</pre>
                </div>
              ))}
            </details>
          </div>
        )}
      </article>

      {busy && (
        <p role="status" className="state-box">
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: '8px' }}>
            <LoaderCircle size={16} className="spin" /> Đang kiểm tra…
          </span>
        </p>
      )}
      {error && (
        <p role="alert" className="error">
          {error}
        </p>
      )}
    </section>
  );
}
