import { useEffect, useState } from 'react';
import { ContentApi, Page } from './content-api';

type Document = { id: string; title: string; documentNumber: string; sourceUrl?: string;
  verificationStatus: string; isActive: boolean; effectiveDate?: string; expirationDate?: string };
export function LegalLibrary({ api }: { api: ContentApi }) {
  const [keyword, setKeyword] = useState(''); const [page, setPage] = useState(1);
  const [result, setResult] = useState<Page<Document>>(); const [loading, setLoading] = useState(false); const [error, setError] = useState('');
  useEffect(() => {
    const controller = new AbortController(); setLoading(true); setError('');
    const query = new URLSearchParams({ keyword, pageIndex: String(page), pageSize: '20' });
    api<Page<Document>>(`/api/documents?${query}`, { signal: controller.signal }).then(setResult)
      .catch(e => { if (!controller.signal.aborted) setError(e.message); })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [api, keyword, page]);
  return <section><h1>Thư viện văn bản luật</h1><label>Tìm theo tiêu đề hoặc số hiệu<input value={keyword} onChange={e => { setKeyword(e.target.value); setPage(1); }}/></label>
    {loading && <p role="status">Đang tải văn bản…</p>}{error && <p role="alert">{error}</p>}
    {!loading && !error && result?.totalCount === 0 && <p>Không tìm thấy văn bản phù hợp.</p>}
    {result?.items.map(d => <article key={d.id}><span>{d.documentNumber} · {d.verificationStatus === 'Verified' && d.isActive ? 'Đã xác minh, đang hoạt động' : 'Chưa đủ điều kiện dùng làm căn cứ RAG'}</span>
      <h2>{d.title}</h2>{d.effectiveDate && <p>Hiệu lực từ {new Date(d.effectiveDate).toLocaleDateString('vi-VN')}</p>}
      {d.expirationDate && <p>Hết hiệu lực {new Date(d.expirationDate).toLocaleDateString('vi-VN')}</p>}
      {d.sourceUrl && <a href={d.sourceUrl} target="_blank" rel="noreferrer">Đọc tại nguồn</a>}</article>)}
    <div className="filters"><button disabled={loading || page <= 1} onClick={() => setPage(p => p - 1)}>Trang trước</button>
      <span>Trang {page}</span><button disabled={loading || page * 20 >= (result?.totalCount ?? 0)} onClick={() => setPage(p => p + 1)}>Trang sau</button></div>
  </section>;
}
