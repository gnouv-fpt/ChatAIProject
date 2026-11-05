import { useEffect, useMemo, useState } from 'react';
import { Download, FileUp, Search } from 'lucide-react';
import { api } from '../../api';
import {
  ProtectedExplanationAnimation,
  type AnimationPayload,
} from '../exams/ProtectedExplanationAnimation';
import './admin-animation-review.css';

type Summary = { number: number; prompt: string; revision: string };
type Detail = AnimationPayload & {
  prompt: string;
  options: { id: string; text: string }[];
  correctOptionIds: string[];
  revision: string;
};
type Status = 'pending' | 'approved' | 'changes';
type RecordItem = { number: number; revision: string; status: Status; notes: string; updatedAt: string };

const storageKey = 'admin-animation-review-v1';

function readRecords(): Record<number, RecordItem> {
  try {
    const value = JSON.parse(localStorage.getItem(storageKey) || '{}') as Record<string, RecordItem>;
    return Object.fromEntries(Object.entries(value).filter(([, item]) =>
      item && Number.isInteger(item.number) && ['pending', 'approved', 'changes'].includes(item.status))
      .map(([key, item]) => [Number(key), item]));
  } catch { return {}; }
}

export function AdminAnimationReview() {
  const [items, setItems] = useState<Summary[]>([]);
  const [selected, setSelected] = useState(486);
  const [detail, setDetail] = useState<Detail | null>(null);
  const [records, setRecords] = useState<Record<number, RecordItem>>(readRecords);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<'all' | Status>('all');
  const [error, setError] = useState('');

  useEffect(() => {
    const controller = new AbortController();
    api<Summary[]>('/admin/animation-reviews', { signal: controller.signal })
      .then(data => { setItems(data); if (data.length) setSelected(data[0].number); })
      .catch(e => { if (!controller.signal.aborted) setError(e.message); });
    return () => controller.abort();
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    setDetail(null);
    api<Detail>(`/admin/animation-reviews/${selected}`, { signal: controller.signal })
      .then(setDetail)
      .catch(e => { if (!controller.signal.aborted) setError(e.message); });
    return () => controller.abort();
  }, [selected]);

  function statusOf(item: Summary): Status {
    const record = records[item.number];
    return record?.revision === item.revision ? record.status : 'approved';
  }

  const visible = useMemo(() => items.filter(item => {
    const status = statusOf(item);
    return (filter === 'all' || status === filter) &&
      (!search || `${item.number} ${item.prompt}`.toLowerCase().includes(search.toLowerCase()));
  }), [items, records, filter, search]);

  const saved = records[selected];
  const current = saved?.revision === detail?.revision ? saved : {
    number: selected,
    revision: detail?.revision ?? '',
    status: 'approved' as Status,
    notes: '',
    updatedAt: '',
  };

  function save(patch: Partial<RecordItem>) {
    const next = { ...current, revision: detail?.revision ?? current.revision, ...patch, updatedAt: new Date().toISOString() };
    setRecords(previous => {
      const value = { ...previous, [selected]: next };
      localStorage.setItem(storageKey, JSON.stringify(value));
      return value;
    });
  }

  function exportJson() {
    const exportedRecords = items.map(item => records[item.number]?.revision === item.revision
      ? records[item.number]
      : { number: item.number, revision: item.revision, status: 'approved' as Status, notes: '', updatedAt: '' });
    const blob = new Blob([JSON.stringify({ format: 'admin-animation-review', version: 1, records: exportedRecords }, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob), link = document.createElement('a');
    link.href = url; link.download = `duyet-mo-phong-${new Date().toISOString().slice(0, 10)}.json`; link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  async function importJson(file?: File) {
    if (!file || file.size > 2_000_000) return;
    try {
      const value = JSON.parse(await file.text()) as { format?: string; version?: number; records?: RecordItem[] };
      if (value.format !== 'admin-animation-review' || value.version !== 1 || !Array.isArray(value.records)) throw new Error();
      const next: Record<number, RecordItem> = {};
      for (const item of value.records) {
        if (!Number.isInteger(item.number) || item.number < 486 || item.number > 600 ||
            !['pending', 'approved', 'changes'].includes(item.status) || typeof item.notes !== 'string' || item.notes.length > 4000) throw new Error();
        next[item.number] = item;
      }
      localStorage.setItem(storageKey, JSON.stringify(next)); setRecords(next); setError('');
    } catch { setError('File kết quả duyệt không hợp lệ.'); }
  }

  const counts = { approved: 0, changes: 0, pending: 0 };
  for (const item of items) counts[statusOf(item)] += 1;

  return (
    <main className="admin-animation-page">
      <header>
        <span className="eyebrow">QUẢN TRỊ · KIỂM DUYỆT NỘI DUNG</span>
        <h1>Duyệt mô phỏng sa hình</h1>
        <p>Các recipe trong catalog này đã được phát hành và mặc định là Đã duyệt. Ghi chú thay đổi được lưu trên trình duyệt; hãy xuất JSON để bàn giao hoặc sao lưu.</p>
      </header>
      {error && <p role="alert" className="error">{error}</p>}
      <div className="admin-animation-counts">
        <span><b>{counts.approved}</b> Đã duyệt</span><span><b>{counts.changes}</b> Cần sửa</span><span><b>{counts.pending}</b> Chưa duyệt</span>
      </div>
      <div className="admin-animation-tools">
        <label><Search size={15} /> <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Tìm số câu hoặc nội dung" /></label>
        <select value={filter} onChange={e => setFilter(e.target.value as typeof filter)} aria-label="Lọc trạng thái">
          <option value="all">Tất cả</option><option value="pending">Chưa duyệt</option><option value="approved">Đã duyệt</option><option value="changes">Cần sửa</option>
        </select>
        <button onClick={exportJson}><Download size={15} /> Xuất JSON</button>
        <label className="admin-animation-import"><FileUp size={15} /> Nhập JSON<input type="file" accept="application/json,.json" onChange={e => void importJson(e.target.files?.[0])} /></label>
      </div>
      <div className="admin-animation-layout">
        <nav aria-label="Danh sách mô phỏng">
          {visible.map(item => <button key={item.number} className={`${statusOf(item)} ${selected === item.number ? 'active' : ''}`} onClick={() => setSelected(item.number)}>Câu {item.number}</button>)}
        </nav>
        <section className="admin-animation-review-card">
          {!detail ? <p role="status">Đang tải mô phỏng…</p> : <>
            <span className="eyebrow">CÂU {detail.number} · REVISION {detail.revision}</span>
            <h2>{detail.prompt}</h2>
            <ol>{detail.options.map(option => <li key={option.id} className={detail.correctOptionIds.includes(option.id) ? 'correct' : ''}>{option.id}. {option.text}{detail.correctOptionIds.includes(option.id) && <strong> · Đáp án đúng</strong>}</li>)}</ol>
            <ProtectedExplanationAnimation key={`${detail.number}-${detail.revision}`} payload={detail} />
            <label className="admin-animation-notes">Ghi chú cần sửa<textarea rows={4} maxLength={4000} value={current.notes} onChange={e => save({ notes: e.target.value })} /></label>
            <div className="admin-animation-actions">
              <button className="approved" onClick={() => save({ status: 'approved' })}>Đã duyệt</button>
              <button className="changes" onClick={() => save({ status: 'changes' })}>Cần sửa</button>
              <button onClick={() => save({ status: 'pending' })}>Để duyệt lại</button>
            </div>
          </>}
        </section>
      </div>
    </main>
  );
}
