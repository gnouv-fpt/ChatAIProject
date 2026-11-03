import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, LoaderCircle } from 'lucide-react';
import { api } from '../../api';
import { ExplanationAnimationLink } from '../questions/ExplanationAnimationLink';
import './exam-review.css';

type Question = {
  questionId: string; version: string; text: string;
  options: { id: string; text: string }[]; correctOptionId: string; selectedOptionId: string | null;
  isCritical: boolean; assets: { id: string; url: string; altText: string }[] | null;
  explanation: string | null; explanationAnimationUrl: string | null;
};
type Review = {
  attemptId: string; examId: string; bankId: string; bankVersion: string;
  correct: number; total: number; isPassed: boolean; submittedAtUtc: string;
  questions: Question[]; animationAllowedHosts: string[]; localAssetOrigin?: string | null;
};
type Filter = 'all' | 'wrong' | 'unanswered';
const outcome = (q: Question) => q.selectedOptionId == null ? 'unanswered'
  : q.selectedOptionId === q.correctOptionId ? 'correct' : 'wrong';
const labels = { correct: 'Trả lời đúng', wrong: 'Trả lời sai', unanswered: 'Chưa trả lời' };

export function ExamReviewPage() {
  const { attemptId } = useParams();
  const navigate = useNavigate();
  const [review, setReview] = useState<Review | null>(null);
  const [error, setError] = useState('');
  const [retry, setRetry] = useState(0);
  const [filter, setFilter] = useState<Filter>('all');
  useEffect(() => {
    const controller = new AbortController();
    setReview(null); setError(''); setFilter('all');
    api<Review>(`/exam-attempts/${encodeURIComponent(attemptId ?? '')}/review`, { signal: controller.signal })
      .then(data => { if (!controller.signal.aborted) setReview(data); })
      .catch(e => { if (!controller.signal.aborted) setError(e.message); });
    return () => controller.abort();
  }, [attemptId, retry]);
  const unanswered = review?.questions.filter(q => outcome(q) === 'unanswered').length ?? 0;
  const wrong = review?.questions.filter(q => outcome(q) === 'wrong').length ?? 0;
  return <main className="exam-review">
    <button className="link-button review-back" onClick={() => navigate(-1)}><ArrowLeft size={16}/>Quay lại</button>
    <span className="eyebrow">KẾT QUẢ LUYỆN THI</span>
    <h1>Xem lại bài làm</h1>
    {!review && !error && <p role="status"><LoaderCircle size={16} className="spin"/> Đang tải kết quả…</p>}
    {error && <div role="alert" className="error">{error}<button className="link-button" onClick={() => setRetry(n => n + 1)}>Thử lại</button></div>}
    {review && <>
      <section className="review-summary" aria-label="Tổng kết bài làm">
        <strong>{review.correct}/{review.total}<span> câu đúng</span></strong>
        <p>{review.isPassed ? 'Đạt' : 'Chưa đạt'} · {wrong} câu sai · {unanswered} câu chưa trả lời</p>
        <p>Nộp lúc {new Date(review.submittedAtUtc).toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' })}</p>
        <p>Phiên bản bộ câu hỏi: {review.bankVersion}</p>
      </section>
      <p className="muted">Đáp án và lời giải theo bản đã lưu khi nộp bài.</p>
      <div className="review-filters" role="group" aria-label="Lọc câu hỏi">
        {([['all', `Tất cả (${review.total})`], ['wrong', `Câu sai (${wrong})`], ['unanswered', `Chưa trả lời (${unanswered})`]] as const)
          .map(([value, label]) => <button key={value} aria-pressed={filter === value} onClick={() => setFilter(value)}>{label}</button>)}
      </div>
      {review.questions.length === 0 && <p>Không có câu hỏi trong bản lưu này.</p>}
      {review.questions.length > 0 && !review.questions.some(q => filter === 'all' || outcome(q) === filter) && <p role="status">Không có câu hỏi trong bộ lọc này.</p>}
      {review.questions.map((q, index) => (filter === 'all' || outcome(q) === filter) && <article className="review-question" key={q.questionId}>
        <div className="review-question-heading"><span>Câu {index + 1}{q.isCritical ? ' · Câu điểm liệt' : ''}</span><strong className={`review-outcome ${outcome(q)}`}>{labels[outcome(q)]}</strong></div>
        <h2>{q.text}</h2>
        {q.assets?.map(asset => <img key={asset.id} src={asset.url} alt={asset.altText} referrerPolicy="no-referrer"/>)}
        <ol className="review-options">
          {q.options.map(option => <li key={option.id} className={option.id === q.correctOptionId ? 'correct-option' : option.id === q.selectedOptionId ? 'selected-option' : ''}>
            <span>{option.text}</span>
            <small>{[option.id === q.selectedOptionId ? 'Bạn chọn' : '', option.id === q.correctOptionId ? 'Đáp án đúng' : ''].filter(Boolean).join(' · ')}</small>
          </li>)}
        </ol>
        <div className="review-explanation"><h3>Lời giải</h3><p>{q.explanation || 'Bản lưu này chưa có lời giải.'}</p>
          <ExplanationAnimationLink url={q.explanationAnimationUrl ?? undefined} allowedHosts={review.animationAllowedHosts} localAssetOrigin={review.localAssetOrigin} canReview/>
          {!q.explanationAnimationUrl && <small>Chưa có mô phỏng cho câu này trong bản lưu.</small>}
        </div>
      </article>)}
      <Link className="link-button" to={`/thi?bank=${encodeURIComponent(review.bankId)}&version=${encodeURIComponent(review.bankVersion)}`}>Luyện đề khác</Link>
    </>}
  </main>;
}
