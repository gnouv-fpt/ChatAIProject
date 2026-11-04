import { useEffect, useMemo, useState } from 'react';
import {
  AlertTriangle,
  CheckCircle2,
  FileCode2,
  FileUp,
  Layers,
  LoaderCircle,
  Send,
  ShieldCheck,
} from 'lucide-react';
import { type Bank, type ContentApi, type Preview } from '../questions/content-api';

type RawBankShape = {
  questions?: {
    id?: string;
    assets?: unknown[];
    explanationAnimationUrl?: string | null;
    isCritical?: boolean;
  }[];
};

export function AdminContent({ api }: { api: ContentApi }) {
  const [banks, setBanks] = useState<Bank[]>([]);
  const [preview, setPreview] = useState<Preview>();
  const [reviewed, setReviewed] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    const controller = new AbortController();
    api<Bank[]>('/api/admin/question-banks', { signal: controller.signal })
      .then(setBanks)
      .catch(e => {
        if (!controller.signal.aborted) setError(e.message);
      });
    return () => controller.abort();
  }, [api]);

  async function run(action: () => Promise<void>) {
    setBusy(true);
    setError('');
    setMessage('');
    try {
      await action();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Yêu cầu thất bại.');
    } finally {
      setBusy(false);
    }
  }

  async function importFile(file?: File) {
    if (!file) return;
    await run(async () => {
      if (file.size > 10 * 1024 * 1024) throw new Error('Gói JSON phải nhỏ hơn 10 MB.');
      const parsed = JSON.parse(await file.text());
      const bank = parsed && typeof parsed === 'object' && 'bank' in parsed ? parsed.bank : parsed;
      setPreview(
        await api<Preview>('/api/admin/question-banks/import', {
          method: 'POST',
          body: JSON.stringify({ bank }),
        })
      );
      setReviewed(false);
      setBanks(await api<Bank[]>('/api/admin/question-banks'));
      setMessage('Đã nhập bản nháp thành công. Hãy kiểm tra bảng tóm tắt ở Bước 2 trước khi xuất bản.');
    });
  }

  async function show(bank: Bank) {
    await run(async () => {
      setPreview(
        await api<Preview>(
          `/api/admin/question-banks/${bank.id}/versions/${encodeURIComponent(bank.version)}/preview`
        )
      );
      setReviewed(false);
    });
  }

  async function publish() {
    if (!preview) return;
    await run(async () => {
      const b = preview.summary;
      const summary = await api<Bank>(
        `/api/admin/question-banks/${b.id}/versions/${encodeURIComponent(b.version)}/publish`,
        {
          method: 'POST',
          body: JSON.stringify({ expectedHash: b.hash, sourceAndAnswersReviewed: reviewed }),
        }
      );
      setPreview({ ...preview, summary });
      setBanks(await api<Bank[]>('/api/admin/question-banks'));
      setMessage('Đã xuất bản phiên bản bất biến.');
    });
  }

  const stats = useMemo(() => {
    if (!preview) return null;
    const raw = (preview.bank ?? {}) as RawBankShape;
    const questions = Array.isArray(raw.questions) ? raw.questions : [];
    const imageCount = questions.reduce((sum, q) => sum + (Array.isArray(q.assets) ? q.assets.length : 0), 0);
    const animationCount = questions.filter(q => Boolean(q.explanationAnimationUrl)).length;
    const criticalCount = questions.filter(q => Boolean(q.isCritical)).length;
    return { imageCount, animationCount, criticalCount };
  }, [preview]);

  const canPublish = Boolean(
    preview && !preview.summary.isPublished && preview.errors.length === 0 && reviewed && !busy
  );

  return (
    <section aria-labelledby="admin-workflow-title">
      <header className="page-header">
        <span className="eyebrow">
          <ShieldCheck size={14} /> QUẢN TRỊ NỘI DUNG · QUY TRÌNH 3 BƯỚC
        </span>
        <h1 id="admin-workflow-title">Quản lý & Xuất bản Ngân hàng Câu hỏi</h1>
        <p>Thực hiện tuần tự: 1. Import gói JSON → 2. Kiểm tra tóm tắt lỗi/cảnh báo → 3. Xuất bản phiên bản bất biến.</p>
      </header>

      {/* Stepper Indicator */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '12px',
          marginBottom: '20px',
        }}
      >
        <div className="account-card" style={{ padding: '14px 18px', borderColor: 'var(--primary)' }}>
          <span className="eyebrow">BƯỚC 1 · IMPORT</span>
          <strong style={{ display: 'block', marginTop: '4px' }}>Nạp gói JSON hoặc chọn phiên bản</strong>
        </div>
        <div
          className="account-card"
          style={{
            padding: '14px 18px',
            borderColor: preview ? 'var(--primary)' : 'var(--border-light)',
            background: preview ? 'var(--primary-soft)' : 'var(--bg-surface)',
          }}
        >
          <span className="eyebrow">BƯỚC 2 · KIỂM TRA</span>
          <strong style={{ display: 'block', marginTop: '4px' }}>
            {preview
              ? `${preview.summary.questionCount} câu · ${preview.errors.length} lỗi`
              : 'Xem tóm tắt câu hỏi, ảnh & lỗi'}
          </strong>
        </div>
        <div
          className="account-card"
          style={{
            padding: '14px 18px',
            borderColor: canPublish || preview?.summary.isPublished ? 'var(--success)' : 'var(--border-light)',
          }}
        >
          <span className="eyebrow">BƯỚC 3 · XUẤT BẢN</span>
          <strong style={{ display: 'block', marginTop: '4px' }}>
            {preview?.summary.isPublished
              ? 'Đã xuất bản chính thức'
              : canPublish
                ? 'Sẵn sàng xuất bản'
                : 'Chờ xác nhận kiểm tra'}
          </strong>
        </div>
      </div>

      {busy && (
        <p role="status" className="state-box">
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: '8px' }}>
            <LoaderCircle size={16} className="spin" /> Đang xử lý…
          </span>
        </p>
      )}
      {error && (
        <p role="alert" className="error">
          {error}
        </p>
      )}
      {message && (
        <p role="status" className="alert-success">
          {message}
        </p>
      )}

      {/* Step 1: Import & Existing Versions */}
      <article>
        <h2 style={{ fontSize: '17px', display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px' }}>
          <FileUp size={18} color="var(--primary)" /> Bước 1: Import gói ngân hàng câu hỏi hoặc chọn bản hiện có
        </h2>
        <label>
          Import ngân hàng (JSON tối đa 10 MB)
          <input
            type="file"
            accept="application/json,.json"
            disabled={busy}
            onChange={e => void importFile(e.target.files?.[0])}
          />
        </label>

        {banks.length > 0 && (
          <div style={{ marginTop: '16px' }}>
            <strong style={{ fontSize: '13.5px', display: 'block', marginBottom: '8px' }}>
              Các phiên bản ngân hàng trong hệ thống ({banks.length}):
            </strong>
            <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
              {banks.map(b => (
                <li key={`${b.id}/${b.version}`}>
                  <button
                    type="button"
                    className={
                      preview?.summary.id === b.id && preview?.summary.version === b.version
                        ? 'btn-primary'
                        : 'btn-secondary'
                    }
                    disabled={busy}
                    onClick={() => void show(b)}
                  >
                    <Layers size={14} /> {b.title} · {b.version} · {b.isPublished ? 'Đã xuất bản' : 'Bản nháp'}
                  </button>
                </li>
              ))}
            </ul>
          </div>
        )}
      </article>

      {/* Step 2 & Step 3: Summary Inspection & Publish */}
      {preview && (
        <article>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '10px', marginBottom: '14px' }}>
            <h2 style={{ fontSize: '18px', margin: 0 }}>
              Bước 2: Xem trước & Kiểm tra — {preview.summary.title}
            </h2>
            <span
              className="ql-badge"
              style={
                preview.summary.isPublished
                  ? { background: 'var(--success-bg)', color: 'var(--success)', borderColor: 'var(--success-border)' }
                  : { background: 'var(--warning-bg)', color: 'var(--warning)', borderColor: 'var(--warning-border)' }
              }
            >
              {preview.summary.isPublished ? 'Đã xuất bản (Bất biến)' : 'Bản nháp (Chờ xuất bản)'}
            </span>
          </div>

          {/* High-level Summary Cards Instead of Forcing Raw JSON Reading */}
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))',
              gap: '12px',
              marginBottom: '16px',
            }}
          >
            <div className="usage-stat">
              <span>Tổng số câu hỏi</span>
              <strong>{preview.summary.questionCount} câu</strong>
            </div>
            <div className="usage-stat">
              <span>Ảnh minh họa</span>
              <strong>{stats?.imageCount ?? 0} ảnh</strong>
            </div>
            <div className="usage-stat">
              <span>Mô phỏng 3D</span>
              <strong>{stats?.animationCount ?? 0} cảnh</strong>
            </div>
            <div className="usage-stat">
              <span>Cấu trúc đề chuẩn</span>
              <strong>
                {preview.summary.profile.questionCount} câu /{' '}
                {Math.ceil(preview.summary.profile.durationSeconds / 60)}p
              </strong>
            </div>
            <div className="usage-stat">
              <span>Lỗi cấu trúc</span>
              <strong style={{ color: preview.errors.length > 0 ? 'var(--danger)' : 'var(--success)' }}>
                {preview.errors.length} lỗi
              </strong>
            </div>
          </div>

          <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
            Nguồn: <strong>{preview.summary.sourceDescription}</strong> · SHA-256: <code>{preview.summary.hash}</code>
          </p>

          {preview.errors.length > 0 ? (
            <div className="error" role="alert">
              <strong style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '6px' }}>
                <AlertTriangle size={16} /> Phát hiện {preview.errors.length} lỗi cần khắc phục trước khi xuất bản:
              </strong>
              {preview.errors.map(e => (
                <p key={e} style={{ margin: '4px 0' }}>
                  • {e}
                </p>
              ))}
            </div>
          ) : (
            <div className="alert-success">
              <CheckCircle2 size={16} style={{ verticalAlign: '-3px', marginRight: '6px' }} />
              <strong>Đạt kiểm tra tự động:</strong> Không có lỗi cấu trúc. Đủ điều kiện đối chiếu và xuất bản.
            </div>
          )}

          {/* Raw JSON moved into collapsible details */}
          <details style={{ margin: '14px 0' }}>
            <summary
              style={{
                cursor: 'pointer',
                fontWeight: 600,
                fontSize: '13.5px',
                color: 'var(--primary)',
                display: 'inline-flex',
                alignItems: 'center',
                gap: '6px',
              }}
            >
              <FileCode2 size={15} /> Xem dữ liệu JSON thô chi tiết (chỉ dành cho đối chiếu kỹ thuật)
            </summary>
            <pre style={{ marginTop: '10px', maxHeight: '360px', overflow: 'auto' }}>
              {JSON.stringify(preview.bank, null, 2)}
            </pre>
          </details>

          {/* Step 3: Publish Gate */}
          <div
            style={{
              marginTop: '18px',
              paddingTop: '16px',
              borderTop: '1.5px dashed var(--border-default)',
            }}
          >
            <h3 style={{ fontSize: '16px', margin: '0 0 10px' }}>Bước 3: Xác nhận & Xuất bản</h3>
            <label
              style={{
                display: 'flex',
                alignItems: 'flex-start',
                gap: '10px',
                padding: '12px 14px',
                background: 'var(--bg-page)',
                border: '1px solid var(--border-default)',
                borderRadius: 'var(--radius-sm)',
                cursor: preview.summary.isPublished ? 'default' : 'pointer',
              }}
            >
              <input
                type="checkbox"
                checked={reviewed}
                disabled={busy || preview.summary.isPublished || preview.errors.length > 0}
                onChange={e => setReviewed(e.target.checked)}
                style={{ width: '18px', height: '18px', marginTop: '2px', accentColor: 'var(--primary)' }}
              />
              <span>Tôi đã đối chiếu nguồn, đáp án, profile và nội dung/hash ảnh.</span>
            </label>

            <button
              type="button"
              className="btn-primary"
              style={{ marginTop: '12px' }}
              disabled={busy || !reviewed || preview.errors.length > 0 || preview.summary.isPublished}
              onClick={() => void publish()}
            >
              <Send size={15} />{' '}
              {preview.summary.isPublished ? 'Phiên bản này đã xuất bản' : 'Xuất bản phiên bản này'}
            </button>
          </div>
        </article>
      )}
    </section>
  );
}
