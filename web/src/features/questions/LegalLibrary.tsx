import { useEffect, useState } from 'react';
import { Calendar, CheckCircle2, ExternalLink, FileText, LoaderCircle, RotateCcw, Search, ShieldAlert } from 'lucide-react';
import { type ContentApi, type Page } from './content-api';
import { useSearchParams } from 'react-router-dom';

type Document = {
  id: string;
  title: string;
  documentNumber: string;
  sourceUrl?: string;
  verificationStatus: string;
  isActive: boolean;
  effectiveDate?: string;
  expirationDate?: string;
};

export function LegalLibrary({ api }: { api: ContentApi }) {
  const [params] = useSearchParams();
  const initialQuery = params.get('q') ?? '';
  const [keyword, setKeyword] = useState(initialQuery);
  const [page, setPage] = useState(1);

  // The topbar search navigates here with ?q=…; follow it when it changes.
  useEffect(() => {
    setKeyword(initialQuery);
    setPage(1);
  }, [initialQuery]);
  const [reload, setReload] = useState(0);
  const [result, setResult] = useState<Page<Document>>();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError('');
    const query = new URLSearchParams({ keyword, pageIndex: String(page), pageSize: '20' });
    api<Page<Document>>(`/api/documents?${query}`, { signal: controller.signal })
      .then(setResult)
      .catch(e => {
        if (!controller.signal.aborted) setError(e.message);
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false);
      });
    return () => controller.abort();
  }, [api, keyword, page, reload]);

  return (
    <section aria-labelledby="legal-lib-title">
      <header className="page-header">
        <span className="eyebrow">
          <FileText size={14} /> TRA CỨU CĂN CỨ PHÁP LÝ
        </span>
        <h1 id="legal-lib-title">Thư viện văn bản luật giao thông</h1>
        <p>
          Danh mục văn bản quy phạm pháp luật đã đối chiếu nguồn, thông tin hiệu lực và trạng thái kích hoạt cho hệ thống
          hỏi đáp RAG.
        </p>
      </header>

      <div
        style={{
          background: 'var(--bg-surface)',
          border: '1px solid var(--border-default)',
          borderRadius: 'var(--radius-md)',
          padding: '18px 22px',
          marginBottom: '20px',
          boxShadow: 'var(--shadow-sm)',
        }}
      >
        <label style={{ margin: 0 }}>
          <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Search size={15} /> Tìm theo tiêu đề hoặc số hiệu văn bản
          </span>
          <input
            placeholder="Nhập số hiệu (VD: 55/VBHN, 168/2024) hoặc tên văn bản…"
            value={keyword}
            onChange={e => {
              setKeyword(e.target.value);
              setPage(1);
            }}
          />
        </label>
      </div>

      {loading && (
        <p role="status" className="state-box">
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: '8px' }}>
            <LoaderCircle size={16} className="spin" /> Đang tải văn bản…
          </span>
        </p>
      )}

      {error && (
        <div role="alert" className="error">
          {error}
          <div>
            <button type="button" className="link-button" onClick={() => setReload(r => r + 1)}>
              <RotateCcw size={14} /> Thử tải lại
            </button>
          </div>
        </div>
      )}

      {!loading && !error && result?.totalCount === 0 && (
        <div className="state-box">
          <strong>Không tìm thấy văn bản phù hợp.</strong>
          <span>Hãy thử từ khóa ngắn hơn hoặc xóa từ khóa tìm kiếm để xem toàn bộ danh mục.</span>
        </div>
      )}

      {result?.items.map(d => {
        const verifiedActive = d.verificationStatus === 'Verified' && d.isActive;
        return (
          <article key={d.id}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '10px', marginBottom: '10px' }}>
              <span className="ql-badge license">{d.documentNumber}</span>
              <span
                className="ql-badge"
                style={
                  verifiedActive
                    ? { background: 'var(--success-bg)', color: 'var(--success)', borderColor: 'var(--success-border)' }
                    : { background: 'var(--warning-bg)', color: 'var(--warning)', borderColor: 'var(--warning-border)' }
                }
              >
                {verifiedActive ? (
                  <>
                    <CheckCircle2 size={13} /> Đã xác minh, đang hoạt động
                  </>
                ) : (
                  <>
                    <ShieldAlert size={13} /> Chưa đủ điều kiện dùng làm căn cứ RAG
                  </>
                )}
              </span>
            </div>

            <h2 style={{ fontSize: '18px', fontWeight: 700, margin: '8px 0 10px', lineHeight: 1.5 }}>{d.title}</h2>

            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '16px', fontSize: '13.5px', color: 'var(--text-secondary)', marginBottom: '12px' }}>
              {d.effectiveDate && (
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: '5px' }}>
                  <Calendar size={14} /> Hiệu lực từ {new Date(d.effectiveDate).toLocaleDateString('vi-VN')}
                </span>
              )}
              {d.expirationDate && (
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: '5px', color: 'var(--danger)' }}>
                  Hết hiệu lực {new Date(d.expirationDate).toLocaleDateString('vi-VN')}
                </span>
              )}
            </div>

            {d.sourceUrl && (
              <a className="btn-outline" style={{ padding: '7px 14px', fontSize: '13px' }} href={d.sourceUrl} target="_blank" rel="noreferrer">
                Đọc tại nguồn <ExternalLink size={13} />
              </a>
            )}
          </article>
        );
      })}

      <div className="ql-pager filters">
        <button
          type="button"
          className="btn-secondary"
          disabled={loading || page <= 1}
          onClick={() => setPage(p => p - 1)}
        >
          Trang trước
        </button>
        <span>
          <strong>Trang {page}</strong>
        </span>
        <button
          type="button"
          className="btn-secondary"
          disabled={loading || page * 20 >= (result?.totalCount ?? 0)}
          onClick={() => setPage(p => p + 1)}
        >
          Trang sau
        </button>
      </div>
    </section>
  );
}
