import { useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import {
  AlertTriangle,
  ArrowLeft,
  BookMarked,
  CheckCircle2,
  Filter,
  LoaderCircle,
  RotateCcw,
  XCircle,
} from 'lucide-react';
import { api } from '../../api';
import { ExplanationAnimationLink } from '../questions/ExplanationAnimationLink';
import './exam-review.css';

type Question = {
  questionId: string;
  version: string;
  text: string;
  options: { id: string; text: string }[];
  correctOptionId: string;
  selectedOptionId: string | null;
  isCritical: boolean;
  assets: { id: string; url: string; altText: string }[] | null;
  explanation: string | null;
  explanationAnimationUrl: string | null;
};

type Review = {
  attemptId: string;
  examId: string;
  bankId: string;
  bankVersion: string;
  correct: number;
  total: number;
  isPassed: boolean;
  submittedAtUtc: string;
  questions: Question[];
  animationAllowedHosts: string[];
  localAssetOrigin?: string | null;
};

type FilterType = 'all' | 'wrong' | 'unanswered' | 'critical';

const outcome = (q: Question) =>
  q.selectedOptionId == null ? 'unanswered' : q.selectedOptionId === q.correctOptionId ? 'correct' : 'wrong';

const labels = {
  correct: 'Trả lời đúng',
  wrong: 'Trả lời sai',
  unanswered: 'Chưa trả lời',
};

export function ExamReviewPage() {
  const { attemptId } = useParams();
  const navigate = useNavigate();
  const [review, setReview] = useState<Review | null>(null);
  const [error, setError] = useState('');
  const [retry, setRetry] = useState(0);
  const [filter, setFilter] = useState<FilterType>('all');
  const [bookmarks, setBookmarks] = useState<Set<string>>(new Set());
  const [bookmarkBusy, setBookmarkBusy] = useState<Set<string>>(new Set());
  const listRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const controller = new AbortController();
    setReview(null);
    setError('');
    setFilter('all');
    api<Review>(`/exam-attempts/${encodeURIComponent(attemptId ?? '')}/review`, { signal: controller.signal })
      .then(data => {
        if (!controller.signal.aborted) setReview(data);
      })
      .catch(e => {
        if (!controller.signal.aborted) setError(e.message);
      });
    return () => controller.abort();
  }, [attemptId, retry]);

  useEffect(() => {
    if (!review?.bankId) return;
    const controller = new AbortController();
    api<{ items: { questionId: string }[] }>(`/learning/bookmarks?bankId=${review.bankId}&pageIndex=1&pageSize=100`, {
      signal: controller.signal,
    })
      .then(res => {
        if (!controller.signal.aborted) setBookmarks(new Set(res.items.map(i => i.questionId)));
      })
      .catch(() => {});
    return () => controller.abort();
  }, [review?.bankId]);

  async function toggleBookmark(questionId: string) {
    const isSaved = bookmarks.has(questionId);
    setBookmarkBusy(prev => new Set(prev).add(questionId));
    try {
      await api(`/learning/bookmarks/${questionId}`, { method: isSaved ? 'DELETE' : 'PUT' });
      setBookmarks(prev => {
        const next = new Set(prev);
        if (isSaved) next.delete(questionId);
        else next.add(questionId);
        return next;
      });
    } catch {
      /* ignore bookmark error in review */
    } finally {
      setBookmarkBusy(prev => {
        const next = new Set(prev);
        next.delete(questionId);
        return next;
      });
    }
  }

  const unanswered = review?.questions.filter(q => outcome(q) === 'unanswered').length ?? 0;
  const wrong = review?.questions.filter(q => outcome(q) === 'wrong').length ?? 0;
  const criticalCount = review?.questions.filter(q => q.isCritical).length ?? 0;
  const criticalFailed = review?.questions.some(q => q.isCritical && outcome(q) !== 'correct') ?? false;

  const matchesFilter = (q: Question) => {
    if (filter === 'all') return true;
    if (filter === 'critical') return q.isCritical;
    return outcome(q) === filter;
  };

  return (
    <main className="exam-review">
      <div className="exam-review-container">
        <button className="link-button review-back" onClick={() => navigate(-1)}>
          <ArrowLeft size={16} /> Quay lại
        </button>

        <header className="page-header">
          <span className="eyebrow">HÀNH TRÌNH SÁT HẠCH · BƯỚC 3 · KẾT QUẢ & XEM LẠI</span>
          <h1>Xem lại bài làm</h1>
          <p>Đáp án, lời giải và mô phỏng theo đúng bản ghi đã lưu tại thời điểm nộp bài.</p>
        </header>

        {!review && !error && (
          <p role="status" className="state-box">
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: '8px' }}>
              <LoaderCircle size={16} className="spin" /> Đang tải kết quả…
            </span>
          </p>
        )}

        {error && (
          <div role="alert" className="error">
            {error}
            <button className="link-button" onClick={() => setRetry(n => n + 1)}>
              Thử lại
            </button>
          </div>
        )}

        {review && (
          <>
            <section
              className={`review-summary ${review.isPassed ? 'passed' : 'failed'}`}
              aria-label="Tổng kết bài làm"
            >
              <div className="review-hero-top">
                <div className="review-score-display">
                  <strong>
                    {review.correct}/{review.total}
                    <span> câu đúng</span>
                  </strong>
                </div>
                <span className={`review-verdict-badge ${review.isPassed ? 'passed' : 'failed'}`}>
                  {review.isPassed ? (
                    <>
                      <CheckCircle2 size={18} /> Đạt yêu cầu
                    </>
                  ) : (
                    <>
                      <XCircle size={18} /> Chưa đạt
                    </>
                  )}
                </span>
              </div>

              <p style={{ margin: '12px 0 6px', fontWeight: 600 }}>
                {review.isPassed ? 'Đạt' : 'Chưa đạt'} · {wrong} câu sai · {unanswered} câu chưa trả lời
              </p>

              <div className="review-breakdown-grid">
                <div className="review-stat-box correct">
                  <span>Số câu đúng</span>
                  <strong>{review.correct}</strong>
                </div>
                <div className="review-stat-box wrong">
                  <span>Số câu sai</span>
                  <strong>{wrong}</strong>
                </div>
                <div className="review-stat-box unanswered">
                  <span>Câu bỏ trống</span>
                  <strong>{unanswered}</strong>
                </div>
              </div>

              {!review.isPassed && criticalFailed && (
                <div className="alert-warning" style={{ margin: '12px 0' }}>
                  <AlertTriangle size={16} style={{ verticalAlign: '-3px', marginRight: '6px' }} />
                  <strong>Chú ý câu điểm liệt:</strong> Trong bài có câu điểm liệt bị trả lời sai hoặc bỏ trống. Hãy lọc xem
                  ngay các câu sai bên dưới để nắm vững quy tắc an toàn bắt buộc.
                </div>
              )}

              <div className="review-meta-row">
                <span>
                  Nộp lúc {new Date(review.submittedAtUtc).toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' })}
                </span>
                <span>Phiên bản bộ câu hỏi: {review.bankVersion}</span>
              </div>

              {/* Three Primary Actions requested by design */}
              <div className="review-primary-actions">
                <button
                  type="button"
                  className="btn-primary"
                  onClick={() => {
                    setFilter(wrong > 0 ? 'wrong' : unanswered > 0 ? 'unanswered' : 'all');
                    listRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
                  }}
                >
                  <Filter size={16} /> Xem câu sai ({wrong})
                </button>

                <Link
                  className="btn-secondary"
                  to={`/tien-do?bank=${encodeURIComponent(review.bankId)}&tab=bookmarks`}
                >
                  <BookMarked size={16} /> Ôn lại câu đã lưu ({bookmarks.size})
                </Link>

                <Link
                  className="btn-outline"
                  to={`/thi?bank=${encodeURIComponent(review.bankId)}&version=${encodeURIComponent(review.bankVersion)}`}
                >
                  <RotateCcw size={16} /> Làm đề khác
                </Link>
              </div>
            </section>

            <div ref={listRef} />

            <div className="review-filters" role="group" aria-label="Lọc câu hỏi">
              {(
                [
                  ['all', `Tất cả (${review.total})`],
                  ['wrong', `Câu sai (${wrong})`],
                  ['unanswered', `Chưa trả lời (${unanswered})`],
                  ...(criticalCount > 0 ? ([['critical', `Câu điểm liệt (${criticalCount})`]] as const) : []),
                ] as const
              ).map(([value, label]) => (
                <button key={value} aria-pressed={filter === value} onClick={() => setFilter(value)}>
                  {label}
                </button>
              ))}
            </div>

            {review.questions.length === 0 && <p className="state-box">Không có câu hỏi trong bản lưu này.</p>}
            {review.questions.length > 0 && !review.questions.some(matchesFilter) && (
              <p role="status" className="state-box">
                Không có câu hỏi trong bộ lọc này.
              </p>
            )}

            {review.questions.map(
              (q, index) =>
                matchesFilter(q) && (
                  <article className="review-question" key={q.questionId}>
                    <div className="review-question-heading">
                      <div className="review-q-badges">
                        <span className="review-q-number">
                          Câu {index + 1}
                          {q.isCritical ? ' · Câu điểm liệt' : ''}
                        </span>
                        {q.isCritical && <span className="review-critical-badge">Điểm liệt</span>}
                      </div>

                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                        <strong className={`review-outcome ${outcome(q)}`}>{labels[outcome(q)]}</strong>
                        <button
                          type="button"
                          className="btn-secondary"
                          style={{ padding: '4px 10px', fontSize: '12px' }}
                          disabled={bookmarkBusy.has(q.questionId)}
                          aria-pressed={bookmarks.has(q.questionId)}
                          onClick={() => void toggleBookmark(q.questionId)}
                        >
                          <BookMarked size={13} />
                          {bookmarks.has(q.questionId) ? 'Đã lưu ôn tập' : 'Lưu câu này'}
                        </button>
                      </div>
                    </div>

                    <h2>{q.text}</h2>

                    {q.assets?.map(asset => (
                      <img key={asset.id} src={asset.url} alt={asset.altText} referrerPolicy="no-referrer" />
                    ))}

                    <ol className="review-options">
                      {q.options.map((option, optIdx) => (
                        <li
                          key={option.id}
                          className={
                            option.id === q.correctOptionId
                              ? 'correct-option'
                              : option.id === q.selectedOptionId
                                ? 'selected-option'
                                : ''
                          }
                        >
                          <span>
                            <strong>{String.fromCharCode(65 + optIdx)}.</strong> {option.text}
                          </span>
                          {(option.id === q.selectedOptionId || option.id === q.correctOptionId) && (
                            <small>
                              {[
                                option.id === q.selectedOptionId ? 'Bạn chọn' : '',
                                option.id === q.correctOptionId ? 'Đáp án đúng' : '',
                              ]
                                .filter(Boolean)
                                .join(' · ')}
                            </small>
                          )}
                        </li>
                      ))}
                    </ol>

                    <div className="review-explanation">
                      <h3>Lời giải & Căn cứ</h3>
                      <p>{q.explanation || 'Bản lưu này chưa có lời giải.'}</p>
                      <ExplanationAnimationLink
                        url={q.explanationAnimationUrl ?? undefined}
                        allowedHosts={review.animationAllowedHosts}
                        localAssetOrigin={review.localAssetOrigin}
                        canReview
                      />
                      {!q.explanationAnimationUrl && <small>Chưa có mô phỏng cho câu này trong bản lưu.</small>}
                    </div>
                  </article>
                )
            )}

            <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap', marginTop: '24px' }}>
              <Link
                className="btn-primary"
                to={`/thi?bank=${encodeURIComponent(review.bankId)}&version=${encodeURIComponent(review.bankVersion)}`}
              >
                Luyện đề khác
              </Link>
              <Link className="btn-secondary" to={`/tien-do?bank=${encodeURIComponent(review.bankId)}&tab=wrong`}>
                Xem danh sách câu sai trong Tiến độ
              </Link>
            </div>
          </>
        )}
      </div>
    </main>
  );
}
