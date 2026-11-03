import { useEffect, useState } from 'react';
import { type Bank, type ContentApi, type Page, type Question, bankPath } from './content-api';
import './question-library.css';

export function QuestionLibrary({ api, onStartPractice }: { api: ContentApi;
  onStartPractice?: (selection: { bankId: string; bankVersion: string; count: number; topic?: string; from?: number; to?: number }) => Promise<void> }) {
  const [banks, setBanks] = useState<Bank[]>([]);
  const [selected, setSelected] = useState('');
  const [topic, setTopic] = useState(''); const [from, setFrom] = useState(''); const [to, setTo] = useState('');
  const [count, setCount] = useState(10); const [page, setPage] = useState(1);
  const [result, setResult] = useState<Page<Question>>();
  const [error, setError] = useState(''); const [loading, setLoading] = useState(false);
  const [bookmarks, setBookmarks] = useState<Set<string>>(new Set());
  const [bookmarkBusy, setBookmarkBusy] = useState<Set<string>>(new Set());
  const [bookmarkLoading, setBookmarkLoading] = useState(false);
  const [bookmarkError, setBookmarkError] = useState('');
  const [bookmarkReload, setBookmarkReload] = useState(0);
  const bank = banks.find(b => `${b.id}/${b.version}` === selected);
  const official = bank?.profile.id.startsWith('gplx-') ?? false;
  useEffect(() => {
    const controller = new AbortController();
    setBookmarks(new Set()); setBookmarkError('');
    if (!bank) return;
    setBookmarkLoading(true);
    async function load() {
      const ids: string[] = [];
      for (let index = 1; ; index++) {
        const result = await api<Page<{ questionId: string }>>(`/api/learning/bookmarks?bankId=${bank!.id}&pageIndex=${index}&pageSize=100`, { signal: controller.signal });
        ids.push(...result.items.map(item => item.questionId));
        if (index * 100 >= result.totalCount) break;
      }
      if (!controller.signal.aborted) setBookmarks(new Set(ids));
    }
    load().catch(e => { if (!controller.signal.aborted) setBookmarkError(e.message); })
      .finally(() => { if (!controller.signal.aborted) setBookmarkLoading(false); });
    return () => controller.abort();
  }, [api, bank, bookmarkReload]);
  async function toggleBookmark(id: string) {
    const removing = bookmarks.has(id);
    setBookmarkBusy(current => new Set(current).add(id)); setBookmarkError('');
    try {
      await api(`/api/learning/bookmarks/${id}`, { method: removing ? 'DELETE' : 'PUT' });
      setBookmarks(current => { const updated = new Set(current); if (removing) updated.delete(id); else updated.add(id); return updated; });
    } catch (e) { setBookmarkError(e instanceof Error ? e.message : 'Không thể lưu đánh dấu.'); }
    finally { setBookmarkBusy(current => { const updated = new Set(current); updated.delete(id); return updated; }); }
  }
  useEffect(() => {
    const controller = new AbortController();
    setLoading(true); setError('');
    api<Bank[]>('/api/question-banks', { signal: controller.signal }).then(setBanks)
      .catch(e => { if (!controller.signal.aborted) setError(String(e.message)); })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [api]);
  useEffect(() => {
    setResult(undefined); setError('');
    if (!bank) return;
    const controller = new AbortController();
    const query = new URLSearchParams({ page: String(page), pageSize: '20' });
    if (topic) query.set('topic', topic); if (from) query.set('from', from); if (to) query.set('to', to);
    setLoading(true);
    api<Page<Question>>(`${bankPath(bank)}/questions?${query}`, { signal: controller.signal }).then(setResult)
      .catch(e => { if (!controller.signal.aborted) setError(String(e.message)); })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [api, bank, topic, from, to, page]);
  async function start() {
    if (!bank || !onStartPractice) return;
    setError(''); setLoading(true);
    try { await onStartPractice({ bankId: bank.id, bankVersion: bank.version, count, topic: topic || undefined,
      from: from ? Number(from) : undefined, to: to ? Number(to) : undefined }); }
    catch (e) { setError(e instanceof Error ? e.message : 'Không thể bắt đầu luyện tập.'); }
    finally { setLoading(false); }
  }
  return <section className="question-library" aria-labelledby="library-title">
    <h1 id="library-title">Thư viện câu hỏi</h1><p>Chọn ngân hàng đã xuất bản và phạm vi muốn học.</p>
    <label>Ngân hàng / phiên bản<select value={selected} onChange={e => { setSelected(e.target.value); setPage(1); }}>
      <option value="">Chọn ngân hàng</option>{banks.map(b => <option key={`${b.id}/${b.version}`} value={`${b.id}/${b.version}`}>{b.title} · {b.version} · {b.questionCount} câu</option>)}
    </select></label>
    {bank && <><p>{bank.sourceDescription} · <a href={bank.sourceUrl} target="_blank" rel="noreferrer">Nguồn dữ liệu</a></p>
      <div className="filters"><label>Chủ đề<input value={topic} onChange={e => { setTopic(e.target.value); setPage(1); }}/></label>
      <label>Từ câu<input type="number" min="1" value={from} onChange={e => { setFrom(e.target.value); setPage(1); }}/></label>
      <label>Đến câu<input type="number" min="1" value={to} onChange={e => { setTo(e.target.value); setPage(1); }}/></label>
      {!official && <label>Số câu luyện<input type="number" min="1" max={result?.totalCount || 1} value={count} onChange={e => setCount(Number(e.target.value))}/></label>}</div>
      {official ? <p>Đây là bank thi thử theo quy tắc sát hạch. Chọn đề hạng B tương ứng trong mục Luyện thi để giữ đúng cấu trúc và thời gian.</p> :
      <button disabled={loading || !onStartPractice || !Number.isInteger(count) || count < 1 || count > (result?.totalCount ?? 0)} onClick={start}>Bắt đầu luyện tập</button>}
      {!onStartPractice && <p>Chức năng làm bài sẽ được nối với Practice API khi module luyện thi được tích hợp.</p>}</>}
    {loading && <p role="status">Đang tải…</p>}{error && <p role="alert">{error}</p>}
    {bookmarkError && <div role="alert"><p>{bookmarkError}</p>
      <button type="button" disabled={bookmarkLoading} onClick={() => setBookmarkReload(value => value + 1)}>Thử tải lại đánh dấu</button></div>}
    {!loading && !banks.length && !error && <p>Chưa có ngân hàng câu hỏi đã xuất bản.</p>}
    {result && <><p>{result.totalCount} câu phù hợp</p>{result.items.map(q => <article key={q.id}>
      <span>{q.topic} · Câu {q.number}</span><h2>{q.text}</h2>
      <button type="button" aria-pressed={bookmarks.has(q.id)} disabled={bookmarkLoading || bookmarkBusy.has(q.id)}
        onClick={() => toggleBookmark(q.id)} aria-label={`${bookmarks.has(q.id) ? 'Bỏ đánh dấu' : 'Đánh dấu'} câu ${q.number}`}>
        {bookmarkBusy.has(q.id) ? 'Đang lưu…' : bookmarks.has(q.id) ? 'Đã đánh dấu' : 'Đánh dấu câu hỏi'}
      </button>
      {q.assets.map(a => <img key={a.id} src={a.url} alt={a.altText} loading="lazy" referrerPolicy="no-referrer"/>)}
      <ol>{q.options.map(o => <li key={o.id}>{o.text}</li>)}</ol><a href={q.sourceUrl} target="_blank" rel="noreferrer">Nguồn câu hỏi</a>
    </article>)}<div className="filters"><button disabled={page <= 1 || loading} onClick={() => setPage(p => p - 1)}>Trang trước</button>
      <span>Trang {page}</span><button disabled={page * 20 >= result.totalCount || loading} onClick={() => setPage(p => p + 1)}>Trang sau</button></div></>}
  </section>;
}
