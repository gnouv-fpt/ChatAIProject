import { useEffect, useState } from 'react';
import type { ReactNode } from 'react';
import { ArrowLeft, BookMarked, ChevronRight, CircleAlert, History, LoaderCircle, Target, Trash2 } from 'lucide-react';
import { api } from '../../api';
import './progress.css';

type TopicProgress = { topic: string; totalQuestions: number; answeredQuestions: number; correctQuestions: number; wrongQuestions: number };
type BankProgress = {
  bankId: string; bankCode: string; bankName: string; bankVersion: number; licenseClass: string | null; bankStatus: string;
  totalQuestions: number; answeredQuestions: number; correctQuestions: number; wrongQuestions: number; unseenQuestions: number;
  bookmarkedQuestions: number; gradedAnswers: number; correctAnswers: number; accuracyPercent: number;
  practiceAttempts: number; completedExams: number; passedExams: number; bestExamScore: number | null; lastActivityAt: string | null;
  topics: TopicProgress[];
};
type QuestionItem = { questionId: string; number: number; topic: string; isCritical: boolean; hasImage: boolean; contentPreview: string; wrongAnswers: number; lastAnsweredAt: string | null };
type BookmarkItem = { questionId: string; number: number; topic: string; contentPreview: string; bookmarkedAt: string };
type AttemptItem = {
  attemptId: string; examTemplateName: string | null; mode: 'Practice' | 'Exam'; status: string; questionCount: number;
  answeredCount: number; correctCount: number | null; score: number | null; isPassed: boolean | null; startedAt: string; submittedAt: string | null;
};
type Paged<T> = { items: T[]; totalCount: number; totalPages: number };
type Tab = 'wrong' | 'unseen' | 'bookmarks' | 'history';

const statusLabels: Record<string, string> = { InProgress: 'Đang làm', Submitted: 'Đã nộp', Expired: 'Hết giờ', Abandoned: 'Bỏ dở' };
const ratio = (part: number, total: number) => total > 0 ? Math.round((part / total) * 100) : 0;
const dateTime = (value: string) => new Date(value).toLocaleString('vi-VN', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });

export function ProgressPage() {
  const [banks, setBanks] = useState<BankProgress[] | null>(null);
  const [selected, setSelected] = useState<string | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    const controller = new AbortController();
    api<BankProgress[]>('/learning/progress', { signal: controller.signal })
      .then(setBanks).catch(e => { if (!controller.signal.aborted) setError(e.message); });
    return () => controller.abort();
  }, []);

  if (selected) return <BankDetail bankId={selected} onBack={() => setSelected(null)}/>;
  return <main className="progress-page">
    <span className="eyebrow">TIẾN ĐỘ HỌC</span>
    <h1>Bạn đã đi được bao xa?</h1>
    <p className="muted">Số liệu chỉ tính từ các câu đã được chấm, theo từng phiên bản bộ câu hỏi.</p>
    {error && <p role="alert" className="error">{error}</p>}
    {!banks && !error && <p className="muted progress-loading"><LoaderCircle size={14} className="spin"/>Đang tải tiến độ…</p>}
    {banks?.length === 0 && <div className="progress-empty"><Target size={22}/><strong>Chưa có bộ câu hỏi nào được xuất bản.</strong><span>Khi bộ câu hỏi được xuất bản và bạn bắt đầu ôn luyện, tiến độ sẽ hiện ở đây.</span></div>}
    <div className="bank-list">
      {banks?.map(bank => <button key={bank.bankId} className="bank-card" onClick={() => setSelected(bank.bankId)}>
        <div className="bank-title"><strong>{bank.bankName}</strong><small>{bank.licenseClass ? `Hạng ${bank.licenseClass} · ` : ''}phiên bản {bank.bankVersion}{bank.bankStatus === 'Retired' ? ' · đã ngừng dùng' : ''}</small></div>
        <ProgressBar correct={bank.correctQuestions} wrong={bank.wrongQuestions} total={bank.totalQuestions}/>
        <div className="bank-numbers">
          <span><b>{bank.answeredQuestions}</b>/{bank.totalQuestions} câu đã làm</span>
          <span><b>{bank.accuracyPercent}%</b> chính xác</span>
          <span><b>{bank.wrongQuestions}</b> câu sai cần ôn</span>
        </div>
        <ChevronRight size={16} className="bank-chevron"/>
      </button>)}
    </div>
  </main>;
}

function ProgressBar({ correct, wrong, total }: { correct: number; wrong: number; total: number }) {
  return <div className="progress-bar" role="img" aria-label={`${correct} đúng, ${wrong} sai trên ${total} câu`}>
    <span className="is-correct" style={{ width: `${ratio(correct, total)}%` }}/>
    <span className="is-wrong" style={{ width: `${ratio(wrong, total)}%` }}/>
  </div>;
}

function BankDetail({ bankId, onBack }: { bankId: string; onBack: () => void }) {
  const [bank, setBank] = useState<BankProgress | null>(null);
  const [tab, setTab] = useState<Tab>('wrong');
  const [error, setError] = useState('');
  const [version, setVersion] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    api<BankProgress>(`/learning/progress/${bankId}`, { signal: controller.signal })
      .then(setBank).catch(e => { if (!controller.signal.aborted) setError(e.message); });
    return () => controller.abort();
  }, [bankId, version]);

  return <main className="progress-page">
    <button className="link-button progress-back" onClick={onBack}><ArrowLeft size={15}/>Tất cả bộ câu hỏi</button>
    {error && <p role="alert" className="error">{error}</p>}
    {!bank ? !error && <p className="muted progress-loading"><LoaderCircle size={14} className="spin"/>Đang tải…</p> : <>
      <span className="eyebrow">{bank.bankCode} · PHIÊN BẢN {bank.bankVersion}</span>
      <h1>{bank.bankName}</h1>
      <div className="progress-stats">
        <Stat label="Đã làm" value={`${bank.answeredQuestions}/${bank.totalQuestions}`}/>
        <Stat label="Đúng ở lần gần nhất" value={String(bank.correctQuestions)}/>
        <Stat label="Tỷ lệ chính xác" value={`${bank.accuracyPercent}%`} hint={`${bank.correctAnswers}/${bank.gradedAnswers} lượt trả lời`}/>
        <Stat label="Lượt luyện tập" value={String(bank.practiceAttempts)}/>
        <Stat label="Bài thi đạt" value={`${bank.passedExams}/${bank.completedExams}`} hint={bank.bestExamScore != null ? `Điểm cao nhất ${bank.bestExamScore}` : undefined}/>
      </div>
      <section className="topic-section">
        <h2>Theo chủ đề</h2>
        {bank.topics.map(topic => <div key={topic.topic} className="topic-row">
          <span>{topic.topic}</span>
          <ProgressBar correct={topic.correctQuestions} wrong={topic.wrongQuestions} total={topic.totalQuestions}/>
          <small>{topic.answeredQuestions}/{topic.totalQuestions}</small>
        </div>)}
        <ul className="progress-legend"><li><i className="is-correct"/>Đúng</li><li><i className="is-wrong"/>Sai</li><li><i/>Chưa làm</li></ul>
      </section>
      <div className="progress-tabs" role="tablist">
        <TabButton tab="wrong" current={tab} onSelect={setTab} icon={<CircleAlert size={14}/>} label={`Câu sai (${bank.wrongQuestions})`}/>
        <TabButton tab="unseen" current={tab} onSelect={setTab} icon={<Target size={14}/>} label={`Chưa làm (${bank.unseenQuestions})`}/>
        <TabButton tab="bookmarks" current={tab} onSelect={setTab} icon={<BookMarked size={14}/>} label={`Đã đánh dấu (${bank.bookmarkedQuestions})`}/>
        <TabButton tab="history" current={tab} onSelect={setTab} icon={<History size={14}/>} label="Lịch sử"/>
      </div>
      <TabContent key={tab} tab={tab} bankId={bankId} onChanged={() => setVersion(value => value + 1)}/>
    </>}
  </main>;
}

function Stat({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return <div className="progress-stat"><span>{label}</span><strong>{value}</strong>{hint && <small>{hint}</small>}</div>;
}

function TabButton({ tab, current, onSelect, icon, label }: { tab: Tab; current: Tab; onSelect: (tab: Tab) => void; icon: ReactNode; label: string }) {
  return <button role="tab" aria-selected={tab === current} className={tab === current ? 'active' : ''} onClick={() => onSelect(tab)}>{icon}{label}</button>;
}

function TabContent({ tab, bankId, onChanged }: { tab: Tab; bankId: string; onChanged: () => void }) {
  const [page, setPage] = useState(1);
  const [data, setData] = useState<Paged<QuestionItem | BookmarkItem | AttemptItem> | null>(null);
  const [error, setError] = useState('');
  const [reload, setReload] = useState(0);
  const path = {
    wrong: `/learning/progress/${bankId}/wrong-questions`,
    unseen: `/learning/progress/${bankId}/unseen-questions`,
    bookmarks: `/learning/bookmarks?bankId=${bankId}`,
    history: `/learning/history?bankId=${bankId}`,
  }[tab];

  useEffect(() => {
    const controller = new AbortController();
    const separator = path.includes('?') ? '&' : '?';
    api<Paged<QuestionItem | BookmarkItem | AttemptItem>>(`${path}${separator}pageIndex=${page}&pageSize=15`, { signal: controller.signal })
      .then(setData).catch(e => { if (!controller.signal.aborted) setError(e.message); });
    return () => controller.abort();
  }, [path, page, reload]);

  async function removeBookmark(questionId: string) {
    try { await api(`/learning/bookmarks/${questionId}`, { method: 'DELETE' }); setReload(value => value + 1); onChanged(); }
    catch (e) { setError((e as Error).message); }
  }

  if (error) return <p role="alert" className="error">{error}</p>;
  if (!data) return <p className="muted progress-loading"><LoaderCircle size={14} className="spin"/>Đang tải…</p>;
  if (data.items.length === 0) return <p className="muted progress-none">{{
    wrong: 'Không có câu sai cần ôn. Tốt lắm!', unseen: 'Bạn đã làm hết các câu trong bộ này.',
    bookmarks: 'Chưa đánh dấu câu nào.', history: 'Chưa có lượt học hoặc thi nào.' }[tab]}</p>;

  return <>
    <ul className="progress-list">
      {tab === 'history'
        ? (data.items as AttemptItem[]).map(attempt => <li key={attempt.attemptId}>
            <span className={`mode-chip ${attempt.mode === 'Exam' ? 'exam' : ''}`}>{attempt.mode === 'Exam' ? 'Thi thử' : 'Luyện tập'}</span>
            <div><strong>{attempt.examTemplateName ?? `${attempt.questionCount} câu`}</strong>
              <small>{dateTime(attempt.startedAt)} · {statusLabels[attempt.status] ?? attempt.status} · đã trả lời {attempt.answeredCount}/{attempt.questionCount}</small></div>
            <span className="attempt-result">{attempt.score != null ? `${attempt.score}/${attempt.questionCount}` : '—'}
              {attempt.isPassed != null && <em className={attempt.isPassed ? 'passed' : 'failed'}>{attempt.isPassed ? 'Đạt' : 'Chưa đạt'}</em>}</span>
          </li>)
        : (data.items as (QuestionItem | BookmarkItem)[]).map(question => <li key={question.questionId}>
            <span className="question-number">{question.number}</span>
            <div><strong>{question.contentPreview}</strong>
              <small>{question.topic}{'isCritical' in question && question.isCritical ? ' · câu điểm liệt' : ''}
                {'wrongAnswers' in question && question.wrongAnswers > 0 ? ` · sai ${question.wrongAnswers} lần` : ''}</small></div>
            {tab === 'bookmarks' && <button className="icon-button" aria-label="Bỏ đánh dấu" onClick={() => removeBookmark(question.questionId)}><Trash2 size={15}/></button>}
          </li>)}
    </ul>
    {data.totalPages > 1 && <div className="progress-pager">
      <button className="link-button" disabled={page <= 1} onClick={() => setPage(page - 1)}>Trang trước</button>
      <span>{page}/{data.totalPages}</span>
      <button className="link-button" disabled={page >= data.totalPages} onClick={() => setPage(page + 1)}>Trang sau</button>
    </div>}
  </>;
}
