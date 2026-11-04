import { useEffect, useState } from 'react';
import type { ReactNode } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import {
  AlertTriangle,
  ArrowLeft,
  BookMarked,
  BookOpen,
  ChartNoAxesColumn,
  CircleAlert,
  Compass,
  History,
  LoaderCircle,
  Play,
  Target,
  Trash2,
} from 'lucide-react';
import { api } from '../../api';
import './progress.css';

type TopicProgress = {
  topic: string;
  totalQuestions: number;
  answeredQuestions: number;
  correctQuestions: number;
  wrongQuestions: number;
};

type BankProgress = {
  bankId: string;
  bankCode: string;
  bankName: string;
  bankVersion: number;
  licenseClass: string | null;
  bankStatus: string;
  totalQuestions: number;
  answeredQuestions: number;
  correctQuestions: number;
  wrongQuestions: number;
  unseenQuestions: number;
  bookmarkedQuestions: number;
  gradedAnswers: number;
  correctAnswers: number;
  accuracyPercent: number;
  practiceAttempts: number;
  completedExams: number;
  passedExams: number;
  bestExamScore: number | null;
  lastActivityAt: string | null;
  topics: TopicProgress[];
};

type QuestionItem = {
  questionId: string;
  number: number;
  topic: string;
  isCritical: boolean;
  hasImage: boolean;
  contentPreview: string;
  wrongAnswers: number;
  lastAnsweredAt: string | null;
};

type BookmarkItem = {
  questionId: string;
  number: number;
  topic: string;
  contentPreview: string;
  bookmarkedAt: string;
};

type AttemptItem = {
  attemptId: string;
  examTemplateName: string | null;
  mode: 'Practice' | 'Exam';
  status: string;
  questionCount: number;
  answeredCount: number;
  correctCount: number | null;
  score: number | null;
  isPassed: boolean | null;
  startedAt: string;
  submittedAt: string | null;
};

type Paged<T> = { items: T[]; totalCount: number; totalPages: number };
type Tab = 'wrong' | 'unseen' | 'bookmarks' | 'history';

const statusLabels: Record<string, string> = {
  InProgress: 'Đang làm',
  Submitted: 'Đã nộp',
  Expired: 'Hết giờ',
  Abandoned: 'Bỏ dở',
};

const ratio = (part: number, total: number) => (total > 0 ? Math.round((part / total) * 100) : 0);
const dateTime = (value: string) =>
  new Date(value).toLocaleString('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });

export function ProgressPage() {
  const [banks, setBanks] = useState<BankProgress[] | null>(null);
  const [search, setSearch] = useSearchParams();
  const selected = search.get('bank');
  const [error, setError] = useState('');

  useEffect(() => {
    const controller = new AbortController();
    api<BankProgress[]>('/learning/progress', { signal: controller.signal })
      .then(setBanks)
      .catch(e => {
        if (!controller.signal.aborted) setError(e.message);
      });
    return () => controller.abort();
  }, []);

  if (selected) return <BankDetail bankId={selected} onBack={() => setSearch({})} />;

  // Compute summary for the 3 core questions: Đã học bao nhiêu · Đang yếu ở đâu · Tiếp tục từ đâu
  const totalQuestionsAll = banks?.reduce((sum, b) => sum + b.totalQuestions, 0) ?? 0;
  const totalAnsweredAll = banks?.reduce((sum, b) => sum + b.answeredQuestions, 0) ?? 0;
  const totalWrongAll = banks?.reduce((sum, b) => sum + b.wrongQuestions, 0) ?? 0;
  const totalBookmarkedAll = banks?.reduce((sum, b) => sum + b.bookmarkedQuestions, 0) ?? 0;
  const weakestBank =
    banks && banks.length > 0
      ? [...banks].sort((a, b) => b.wrongQuestions - a.wrongQuestions || a.accuracyPercent - b.accuracyPercent)[0]
      : null;
  const nextBank =
    banks && banks.length > 0
      ? banks.find(b => b.wrongQuestions > 0) ?? banks.find(b => b.unseenQuestions > 0) ?? banks[0]
      : null;

  return (
    <main className="progress-page">
      <div className="progress-container">
        <header className="page-header">
          <span className="eyebrow">
            <ChartNoAxesColumn size={14} /> HÀNH TRÌNH ÔN LUYỆN · BƯỚC 4 · TIẾN ĐỘ HỌC
          </span>
          <h1>Bạn đã đi được bao xa?</h1>
          <p>Theo dõi mức độ nắm vững kiến thức, nhận diện phần còn yếu và chọn bước học tiếp theo.</p>
        </header>

        {/* Pinterest 4-Card Bento Analytics Row */}
        <div className="bento-kpi-row" role="region" aria-label="Chỉ số tiến độ tổng hợp">
          <div className="bento-kpi-card is-hero">
            <div className="bkc-top">
              <span>Tổng câu đã hoàn thành</span>
              <span className="bkc-icon-circle"><ChartNoAxesColumn size={15} /></span>
            </div>
            <div className="bkc-value">
              {totalAnsweredAll}/{totalQuestionsAll || 600} <small>câu</small>
            </div>
            <div className="bkc-foot">
              <span className="bkc-badge">▲ {ratio(totalAnsweredAll, totalQuestionsAll || 600)}% độ phủ</span>
              <span>Lưu {totalBookmarkedAll} câu khó</span>
            </div>
          </div>

          <div className="bento-kpi-card">
            <div className="bkc-top">
              <span>Câu trả lời sai cần ôn</span>
              <span className="bkc-icon-circle"><AlertTriangle size={15} /></span>
            </div>
            <div className="bkc-value">
              {totalWrongAll} <small>câu sai</small>
            </div>
            <div className="bkc-foot">
              <span className="bkc-trend warn">
                {weakestBank && weakestBank.wrongQuestions > 0
                  ? `● Tập trung tại ${weakestBank.bankName}`
                  : '● Sẵn sàng kiểm tra chuyên sâu'}
              </span>
            </div>
          </div>

          <div className="bento-kpi-card">
            <div className="bkc-top">
              <span>Câu đã đánh dấu</span>
              <span className="bkc-icon-circle"><BookMarked size={15} /></span>
            </div>
            <div className="bkc-value">
              {totalBookmarkedAll} <small>đã lưu</small>
            </div>
            <div className="bkc-foot">
              <span className="bkc-trend up">● Ôn lại nhanh trước giờ thi</span>
            </div>
          </div>

          <div className="bento-kpi-card is-dark-telemetry">
            <div className="bkc-top">
              <span>Bước tiếp theo khuyến nghị</span>
              <span className="bkc-live-dot" />
            </div>
            <div className="bkc-value" style={{ fontSize: '20px' }}>
              {nextBank
                ? nextBank.wrongQuestions > 0
                  ? `Ôn ${nextBank.wrongQuestions} câu sai`
                  : `Học ${nextBank.unseenQuestions} câu mới`
                : 'Luyện đề chuẩn'}
            </div>
            <div className="bkc-foot">
              <Link to="/thi" className="bkc-inline-btn">
                <Play size={12} /> Vào phòng Thi thử
              </Link>
            </div>
          </div>
        </div>

        {/* Pinterest Visual Analytics Bento Grid */}
        <div className="bento-dashboard-grid" style={{ marginBottom: '22px' }}>
          <div className="bento-card bento-analytics-card">
            <div className="bento-card-head">
              <div>
                <span className="bento-eyebrow">BIỂU ĐỒ NĂNG LỰC CHUYÊN ĐỀ</span>
                <h2>Độ vững kiến thức theo nhóm nội dung</h2>
              </div>
              <div className="bento-legend-pills">
                <span><i className="dot-solid" /> Đã nắm vững</span>
                <span><i className="dot-striped" /> Cần luyện thêm</span>
              </div>
            </div>
            <div className="pinterest-bar-chart">
              {[
                { label: 'Quy tắc', pct: 86, sub: '166 câu', style: 'solid' },
                { label: 'Biển báo', pct: 92, sub: '182 câu', style: 'accent' },
                { label: 'Sa hình 3D', pct: 64, sub: '114 câu', style: 'striped' },
                { label: 'Nghiệp vụ', pct: 54, sub: '37 câu', style: 'striped' },
                { label: 'Đạo đức', pct: 88, sub: '21 câu', style: 'soft' },
                { label: 'Kỹ thuật', pct: 72, sub: '80 câu', style: 'solid' },
              ].map(bar => (
                <div key={bar.label} className="pbc-column" style={{ cursor: 'default' }}>
                  <span className="pbc-pill-tag">{bar.pct}%</span>
                  <div className="pbc-bar-track">
                    <div className={`pbc-bar-fill style-${bar.style}`} style={{ height: `${bar.pct}%` }} />
                  </div>
                  <strong className="pbc-label">{bar.label}</strong>
                  <small className="pbc-sub">{bar.sub}</small>
                </div>
              ))}
            </div>
          </div>

          <div className="bento-card bento-gauge-card">
            <div className="bento-card-head compact">
              <div>
                <span className="bento-eyebrow">MỤC TIÊU VƯỢT QUA SÁT HẠCH</span>
                <h2>Tỷ lệ đạt chuẩn mục tiêu</h2>
              </div>
            </div>
            <div className="pinterest-gauge-wrap">
              <svg viewBox="0 0 220 125" className="pinterest-gauge-svg" aria-hidden="true">
                <path
                  d="M 22 108 A 88 88 0 0 1 198 108"
                  fill="none"
                  stroke="#e4eeec"
                  strokeWidth="20"
                  strokeLinecap="round"
                />
                <path
                  d="M 22 108 A 88 88 0 0 1 198 108"
                  fill="none"
                  stroke="#0b7568"
                  strokeWidth="20"
                  strokeLinecap="round"
                  strokeDasharray="276"
                  strokeDashoffset={Math.round(276 * (1 - (weakestBank?.accuracyPercent || 85) / 100))}
                />
              </svg>
              <div className="pinterest-gauge-center">
                <strong>{weakestBank?.accuracyPercent || 85}%</strong>
                <span>Mục tiêu đạt</span>
              </div>
            </div>
            <div className="gauge-legend-row">
              <span><i className="gl-dot solid" /> Câu đúng</span>
              <span><i className="gl-dot coral" /> Câu sai ({totalWrongAll})</span>
              <span><i className="gl-dot mint" /> Đã lưu ({totalBookmarkedAll})</span>
            </div>
          </div>
        </div>

        {error && (
          <p role="alert" className="error">
            {error}
          </p>
        )}
        {!banks && !error && (
          <p className="muted progress-loading">
            <LoaderCircle size={16} className="spin" />
            Đang tải tiến độ…
          </p>
        )}
        {banks?.length === 0 && (
          <div className="progress-empty">
            <Target size={24} color="var(--primary)" />
            <strong>Chưa có bộ câu hỏi nào được xuất bản.</strong>
            <span>Khi bộ câu hỏi được xuất bản và bạn bắt đầu ôn luyện, tiến độ sẽ hiện ở đây.</span>
          </div>
        )}

        {banks && banks.length > 0 && (
          <>
            <section className="progress-core-grid" aria-label="Tổng quan định hướng học tập">
              <article className="progress-core-card">
                <div>
                  <span className="progress-core-label">
                    <ChartNoAxesColumn size={14} /> 1. Đã học bao nhiêu
                  </span>
                  <h2>
                    {totalAnsweredAll}/{totalQuestionsAll} câu
                  </h2>
                  <p>
                    Đã hoàn thành <strong>{ratio(totalAnsweredAll, totalQuestionsAll)}%</strong> tổng ngân hàng câu hỏi · Đã
                    lưu <strong>{totalBookmarkedAll}</strong> câu đánh dấu.
                  </p>
                </div>
              </article>

              <article className="progress-core-card">
                <div>
                  <span className="progress-core-label">
                    <AlertTriangle size={14} /> 2. Đang yếu ở đâu
                  </span>
                  <h2>
                    {totalWrongAll > 0
                      ? `${totalWrongAll} câu đang trả lời sai`
                      : totalAnsweredAll > 0
                        ? 'Chưa có câu sai tồn đọng'
                        : 'Chưa có dữ liệu chấm'}
                  </h2>
                  <p>
                    {weakestBank && weakestBank.wrongQuestions > 0
                      ? `Tập trung nhiều nhất tại "${weakestBank.bankName}" (${weakestBank.wrongQuestions} câu sai, độ chính xác ${weakestBank.accuracyPercent}%).`
                      : 'Hãy làm bài luyện tập hoặc thi thử để hệ thống thống kê các chủ đề bạn dễ nhầm lẫn.'}
                  </p>
                </div>
              </article>

              <article className="progress-core-card highlight">
                <div>
                  <span className="progress-core-label">
                    <Compass size={14} /> 3. Tiếp tục từ đâu
                  </span>
                  <h2>
                    {nextBank
                      ? nextBank.wrongQuestions > 0
                        ? `Ôn ${nextBank.wrongQuestions} câu sai`
                        : `Học tiếp ${nextBank.unseenQuestions} câu mới`
                      : 'Bắt đầu luyện đề'}
                  </h2>
                  <p>
                    {nextBank
                      ? `Bộ đề khuyến nghị: ${nextBank.bankName} (Phiên bản ${nextBank.bankVersion}).`
                      : 'Chọn một bộ câu hỏi bên dưới để bắt đầu.'}
                  </p>
                </div>
                {nextBank && (
                  <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                    <button
                      type="button"
                      className="btn-primary"
                      onClick={() =>
                        setSearch({
                          bank: nextBank.bankId,
                          tab: nextBank.wrongQuestions > 0 ? 'wrong' : 'unseen',
                        })
                      }
                    >
                      {nextBank.wrongQuestions > 0 ? 'Mở danh sách câu sai' : 'Xem câu chưa học'}
                    </button>
                    <Link
                      className="btn-secondary"
                      to={`/thi?bank=${encodeURIComponent(nextBank.bankId)}&version=${encodeURIComponent(String(nextBank.bankVersion))}`}
                    >
                      Làm đề ngay
                    </Link>
                  </div>
                )}
              </article>
            </section>

            <h2 style={{ fontSize: '18px', margin: '8px 0 12px' }}>Tiến độ theo từng bộ câu hỏi</h2>
            <div className="bank-list">
              {banks.map(bank => (
                <article key={bank.bankId} className="bank-card">
                  <div className="bank-card-header">
                    <div className="bank-title">
                      <strong>{bank.bankName}</strong>
                      <small>
                        {bank.licenseClass ? `Hạng ${bank.licenseClass} · ` : ''}Phiên bản {bank.bankVersion}
                        {bank.bankStatus === 'Retired' ? ' · đã ngừng dùng' : ''}
                      </small>
                    </div>
                    <button
                      type="button"
                      className="btn-outline"
                      onClick={() => setSearch({ bank: bank.bankId })}
                    >
                      Chi tiết bộ câu hỏi
                    </button>
                  </div>

                  <ProgressBar
                    correct={bank.correctQuestions}
                    wrong={bank.wrongQuestions}
                    total={bank.totalQuestions}
                  />

                  <div className="bank-numbers">
                    <span>
                      <b>{bank.answeredQuestions}</b>/{bank.totalQuestions} câu đã làm
                    </span>
                    <span>
                      <b>{bank.accuracyPercent}%</b> chính xác
                    </span>
                    <span>
                      <b>{bank.wrongQuestions}</b> câu sai cần ôn
                    </span>
                    <span>
                      <b>{bank.unseenQuestions}</b> câu chưa học
                    </span>
                    <span>
                      <b>{bank.bookmarkedQuestions}</b> câu đã lưu
                    </span>
                  </div>

                  <div className="bank-shortcut-row" role="group" aria-label={`Danh sách học tập của ${bank.bankName}`}>
                    <button
                      type="button"
                      className="bank-shortcut-btn"
                      onClick={() => setSearch({ bank: bank.bankId, tab: 'wrong' })}
                    >
                      <CircleAlert size={14} /> Câu sai ({bank.wrongQuestions})
                    </button>
                    <button
                      type="button"
                      className="bank-shortcut-btn"
                      onClick={() => setSearch({ bank: bank.bankId, tab: 'unseen' })}
                    >
                      <Target size={14} /> Chưa học ({bank.unseenQuestions})
                    </button>
                    <button
                      type="button"
                      className="bank-shortcut-btn"
                      onClick={() => setSearch({ bank: bank.bankId, tab: 'bookmarks' })}
                    >
                      <BookMarked size={14} /> Đã lưu ({bank.bookmarkedQuestions})
                    </button>
                    <button
                      type="button"
                      className="bank-shortcut-btn"
                      onClick={() => setSearch({ bank: bank.bankId, tab: 'history' })}
                    >
                      <History size={14} /> Lịch sử bài làm ({bank.practiceAttempts + bank.completedExams})
                    </button>
                  </div>
                </article>
              ))}
            </div>
          </>
        )}
      </div>
    </main>
  );
}

function ProgressBar({ correct, wrong, total }: { correct: number; wrong: number; total: number }) {
  return (
    <div className="progress-bar" role="img" aria-label={`${correct} đúng, ${wrong} sai trên ${total} câu`}>
      <span className="is-correct" style={{ width: `${ratio(correct, total)}%` }} />
      <span className="is-wrong" style={{ width: `${ratio(wrong, total)}%` }} />
    </div>
  );
}

function BankDetail({ bankId, onBack }: { bankId: string; onBack: () => void }) {
  const [bank, setBank] = useState<BankProgress | null>(null);
  const [search, setSearch] = useSearchParams();
  const requestedTab = search.get('tab');
  const tab: Tab =
    requestedTab === 'unseen' || requestedTab === 'bookmarks' || requestedTab === 'history' ? requestedTab : 'wrong';
  const setTab = (value: Tab) => setSearch({ bank: bankId, tab: value }, { replace: true });
  const [error, setError] = useState('');
  const [version, setVersion] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    api<BankProgress>(`/learning/progress/${bankId}`, { signal: controller.signal })
      .then(setBank)
      .catch(e => {
        if (!controller.signal.aborted) setError(e.message);
      });
    return () => controller.abort();
  }, [bankId, version]);

  return (
    <main className="progress-page">
      <div className="progress-container">
        <button className="link-button progress-back" onClick={onBack}>
          <ArrowLeft size={15} /> Tất cả bộ câu hỏi
        </button>
        {error && (
          <p role="alert" className="error">
            {error}
          </p>
        )}
        {!bank ? (
          !error && (
            <p className="muted progress-loading">
              <LoaderCircle size={15} className="spin" />
              Đang tải…
            </p>
          )
        ) : (
          <>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '12px' }}>
              <div>
                <span className="eyebrow">
                  {bank.bankCode} · PHIÊN BẢN {bank.bankVersion}
                </span>
                <h1 style={{ margin: '6px 0 8px' }}>{bank.bankName}</h1>
              </div>
              <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
                <Link
                  className="btn-secondary"
                  to={`/hoc?bank=${encodeURIComponent(bank.bankId)}&version=${encodeURIComponent(String(bank.bankVersion))}`}
                >
                  <BookOpen size={15} /> Học bộ này
                </Link>
                <Link
                  className="btn-primary"
                  to={`/thi?bank=${encodeURIComponent(bank.bankId)}&version=${encodeURIComponent(String(bank.bankVersion))}`}
                >
                  <Play size={15} /> Luyện thi bộ này
                </Link>
              </div>
            </div>

            <div className="progress-stats">
              <Stat label="Đã làm" value={`${bank.answeredQuestions}/${bank.totalQuestions}`} />
              <Stat label="Đúng ở lần gần nhất" value={String(bank.correctQuestions)} />
              <Stat
                label="Tỷ lệ chính xác"
                value={`${bank.accuracyPercent}%`}
                hint={`${bank.correctAnswers}/${bank.gradedAnswers} lượt trả lời`}
              />
              <Stat label="Lượt luyện tập" value={String(bank.practiceAttempts)} />
              <Stat
                label="Bài thi đạt"
                value={`${bank.passedExams}/${bank.completedExams}`}
                hint={bank.bestExamScore != null ? `Điểm cao nhất ${bank.bestExamScore}` : undefined}
              />
            </div>

            {bank.topics.length > 0 && (
              <section className="topic-section">
                <h2>Theo chủ đề</h2>
                {bank.topics.map(topic => (
                  <div key={topic.topic} className="topic-row">
                    <span>{topic.topic}</span>
                    <ProgressBar
                      correct={topic.correctQuestions}
                      wrong={topic.wrongQuestions}
                      total={topic.totalQuestions}
                    />
                    <small>
                      {topic.answeredQuestions}/{topic.totalQuestions}
                    </small>
                  </div>
                ))}
                <ul className="progress-legend">
                  <li>
                    <i className="is-correct" />
                    Đúng
                  </li>
                  <li>
                    <i className="is-wrong" />
                    Sai
                  </li>
                  <li>
                    <i />
                    Chưa làm
                  </li>
                </ul>
              </section>
            )}

            <div className="progress-tabs" role="tablist">
              <TabButton
                tab="wrong"
                current={tab}
                onSelect={setTab}
                icon={<CircleAlert size={15} />}
                label={`Câu sai (${bank.wrongQuestions})`}
              />
              <TabButton
                tab="unseen"
                current={tab}
                onSelect={setTab}
                icon={<Target size={15} />}
                label={`Chưa làm (${bank.unseenQuestions})`}
              />
              <TabButton
                tab="bookmarks"
                current={tab}
                onSelect={setTab}
                icon={<BookMarked size={15} />}
                label={`Đã đánh dấu (${bank.bookmarkedQuestions})`}
              />
              <TabButton
                tab="history"
                current={tab}
                onSelect={setTab}
                icon={<History size={15} />}
                label="Lịch sử"
              />
            </div>

            <TabContent
              key={tab}
              tab={tab}
              bankId={bankId}
              bankVersion={bank.bankVersion}
              onChanged={() => setVersion(value => value + 1)}
            />
          </>
        )}
      </div>
    </main>
  );
}

function Stat({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="progress-stat">
      <span>{label}</span>
      <strong>{value}</strong>
      {hint && <small>{hint}</small>}
    </div>
  );
}

function TabButton({
  tab,
  current,
  onSelect,
  icon,
  label,
}: {
  tab: Tab;
  current: Tab;
  onSelect: (tab: Tab) => void;
  icon: ReactNode;
  label: string;
}) {
  return (
    <button
      role="tab"
      aria-selected={tab === current}
      className={tab === current ? 'active' : ''}
      onClick={() => onSelect(tab)}
    >
      {icon}
      {label}
    </button>
  );
}

function TabContent({
  tab,
  bankId,
  bankVersion,
  onChanged,
}: {
  tab: Tab;
  bankId: string;
  bankVersion: number;
  onChanged: () => void;
}) {
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
    api<Paged<QuestionItem | BookmarkItem | AttemptItem>>(`${path}${separator}pageIndex=${page}&pageSize=15`, {
      signal: controller.signal,
    })
      .then(setData)
      .catch(e => {
        if (!controller.signal.aborted) setError(e.message);
      });
    return () => controller.abort();
  }, [path, page, reload]);

  async function removeBookmark(questionId: string) {
    try {
      await api(`/learning/bookmarks/${questionId}`, { method: 'DELETE' });
      setReload(value => value + 1);
      onChanged();
    } catch (e) {
      setError((e as Error).message);
    }
  }

  if (error)
    return (
      <p role="alert" className="error">
        {error}
      </p>
    );
  if (!data)
    return (
      <p className="muted progress-loading">
        <LoaderCircle size={15} className="spin" />
        Đang tải…
      </p>
    );
  if (data.items.length === 0)
    return (
      <p className="muted progress-none">
        {
          {
            wrong: 'Không có câu sai cần ôn. Tốt lắm!',
            unseen: 'Bạn đã làm hết các câu trong bộ này.',
            bookmarks: 'Chưa đánh dấu câu nào.',
            history: 'Chưa có lượt học hoặc thi nào.',
          }[tab]
        }
      </p>
    );

  return (
    <>
      <ul className="progress-list">
        {tab === 'history'
          ? (data.items as AttemptItem[]).map(attempt => (
              <li key={attempt.attemptId}>
                <span className={`mode-chip ${attempt.mode === 'Exam' ? 'exam' : ''}`}>
                  {attempt.mode === 'Exam' ? 'Thi thử' : 'Luyện tập'}
                </span>
                <div>
                  <strong>{attempt.examTemplateName ?? `${attempt.questionCount} câu`}</strong>
                  <small>
                    {dateTime(attempt.startedAt)} · {statusLabels[attempt.status] ?? attempt.status} · đã trả lời{' '}
                    {attempt.answeredCount}/{attempt.questionCount}
                  </small>
                </div>
                <span className="attempt-result">
                  {attempt.score != null ? `${attempt.score}/${attempt.questionCount}` : '—'}
                  {attempt.isPassed != null && (
                    <em className={attempt.isPassed ? 'passed' : 'failed'}>
                      {attempt.isPassed ? 'Đạt' : 'Chưa đạt'}
                    </em>
                  )}
                  {attempt.status === 'Submitted' && (
                    <Link className="link-button" to={'/ket-qua/' + attempt.attemptId}>
                      Xem bài làm
                    </Link>
                  )}
                </span>
              </li>
            ))
          : (data.items as (QuestionItem | BookmarkItem)[]).map(question => (
              <li key={question.questionId}>
                <span className="question-number">#{question.number}</span>
                <div>
                  <strong>{question.contentPreview}</strong>
                  <small>
                    {question.topic}
                    {'isCritical' in question && question.isCritical ? ' · Câu điểm liệt' : ''}
                    {'wrongAnswers' in question && question.wrongAnswers > 0
                      ? ` · Sai ${question.wrongAnswers} lần`
                      : ''}
                  </small>
                </div>
                <Link
                  className="btn-secondary"
                  style={{ padding: '6px 10px', fontSize: '12px' }}
                  to={`/hoc?bank=${encodeURIComponent(bankId)}&version=${encodeURIComponent(String(bankVersion))}`}
                >
                  Ôn câu này
                </Link>
                {tab === 'bookmarks' && (
                  <button
                    className="icon-button"
                    aria-label="Bỏ đánh dấu"
                    onClick={() => void removeBookmark(question.questionId)}
                  >
                    <Trash2 size={15} />
                  </button>
                )}
              </li>
            ))}
      </ul>
      {data.totalPages > 1 && (
        <div className="progress-pager">
          <button className="btn-secondary" disabled={page <= 1} onClick={() => setPage(page - 1)}>
            Trang trước
          </button>
          <span>
            Trang <strong>{page}</strong> / {data.totalPages}
          </span>
          <button className="btn-secondary" disabled={page >= data.totalPages} onClick={() => setPage(page + 1)}>
            Trang sau
          </button>
        </div>
      )}
    </>
  );
}
