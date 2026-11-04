import { useEffect, useState } from 'react';
import {
  ArrowUpRight,
  BookMarked,
  BookOpen,
  Box,
  CheckCircle2,
  Compass,
  ExternalLink,
  Filter,
  Layers,
  LoaderCircle,
  Play,
  RotateCcw,
  ShieldAlert,
  Sparkles,
} from 'lucide-react';
import { type Bank, type ContentApi, type Page, type Question, bankPath } from './content-api';
import { TrafficScene } from '../../components/TrafficScene';
import { ApiError } from '../../api';
import './question-library.css';

type BankProgressOverview = {
  bankId: string;
  bankVersion: number;
  licenseClass: string | null;
  totalQuestions: number;
  answeredQuestions: number;
  correctQuestions: number;
  wrongQuestions: number;
  bookmarkedQuestions: number;
  accuracyPercent: number;
};

type BookmarkRecord = {
  questionId: string;
  number?: number;
  topic?: string;
  contentPreview?: string;
};

function inferLicenseLabel(bank: Bank, progress?: BankProgressOverview): string {
  if (progress?.licenseClass) return `Hạng ${progress.licenseClass}`;
  const pid = bank.profile.id.toLowerCase();
  if (pid.includes('gplx-b') || bank.title.includes('Hạng B') || bank.title.includes('hạng B')) return 'Hạng B';
  if (pid.includes('gplx-a') || bank.title.includes('Hạng A')) return 'Hạng A';
  if (pid.includes('gplx-c') || bank.title.includes('Hạng C')) return 'Hạng C';
  return 'Đường bộ';
}

export function QuestionLibrary({
  api,
  onStartPractice,
}: {
  api: ContentApi;
  onStartPractice?: (selection: {
    bankId: string;
    bankVersion: string;
    count: number;
    topic?: string;
    from?: number;
    to?: number;
  }) => Promise<void>;
}) {
  const [banks, setBanks] = useState<Bank[]>([]);
  const [progressMap, setProgressMap] = useState<Record<string, BankProgressOverview>>({});
  const [selected, setSelected] = useState('');
  const [topic, setTopic] = useState('');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [onlySaved, setOnlySaved] = useState(false);
  const [count, setCount] = useState(10);
  const [page, setPage] = useState(1);
  const [result, setResult] = useState<Page<Question>>();
  const [error, setError] = useState('');
  const [loginRequired, setLoginRequired] = useState(false);
  const [loading, setLoading] = useState(false);
  const [reload, setReload] = useState(0);
  const [showScene, setShowScene] = useState(true);
  const [bookmarks, setBookmarks] = useState<Set<string>>(new Set());
  const [bookmarkItems, setBookmarkItems] = useState<BookmarkRecord[]>([]);
  const [bookmarkBusy, setBookmarkBusy] = useState<Set<string>>(new Set());
  const [bookmarkLoading, setBookmarkLoading] = useState(false);
  const [bookmarkError, setBookmarkError] = useState('');
  const [bookmarkReload, setBookmarkReload] = useState(0);

  const bank = banks.find(b => `${b.id}/${b.version}` === selected);
  const official = bank?.profile.id.startsWith('gplx-') ?? false;
  const hasActiveFilter = Boolean(topic.trim() || from.trim() || to.trim() || onlySaved);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError('');
    setLoginRequired(false);
    Promise.all([
      api<Bank[]>('/api/question-banks', { signal: controller.signal }),
      api<BankProgressOverview[]>('/api/learning/progress', { signal: controller.signal }).catch(
        () => [] as BankProgressOverview[]
      ),
    ])
      .then(([bankList, progressList]) => {
        if (controller.signal.aborted) return;
        setBanks(bankList);
        const byKey: Record<string, BankProgressOverview> = {};
        for (const item of progressList) {
          byKey[`${item.bankId}/${item.bankVersion}`] = item;
          byKey[item.bankId] = item;
        }
        setProgressMap(byKey);

        const params = new URLSearchParams(window.location.search);
        const queryBank = params.get('bank');
        const queryVersion = params.get('version');
        const querySaved = params.get('saved');
        if (querySaved === '1') setOnlySaved(true);
        if (queryBank) {
          const matched =
            bankList.find(b => b.id === queryBank && (!queryVersion || b.version === queryVersion)) ??
            bankList.find(b => b.id === queryBank);
          if (matched) {
            setSelected(`${matched.id}/${matched.version}`);
            return;
          }
        }
        if (bankList.length === 1) {
          setSelected(`${bankList[0].id}/${bankList[0].version}`);
        }
      })
      .catch(caught => {
        if (controller.signal.aborted) return;
        if (caught instanceof ApiError && caught.status === 401) {
          setLoginRequired(true);
          setError('Bạn đang xem giao diện demo. Đăng nhập để xem ngân hàng câu hỏi và dữ liệu học tập thật.');
        } else {
          setError('Không tải được ngân hàng câu hỏi. Máy chủ dữ liệu local chưa sẵn sàng.');
        }
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false);
      });
    return () => controller.abort();
  }, [api, reload]);

  useEffect(() => {
    const controller = new AbortController();
    setBookmarks(new Set());
    setBookmarkItems([]);
    setBookmarkError('');
    if (!bank) {
      setBookmarkLoading(false);
      return () => controller.abort();
    }
    setBookmarkLoading(true);
    api<Page<BookmarkRecord>>(
      `/api/learning/banks/${encodeURIComponent(bank.id)}/bookmarks?page=1&pageSize=100`,
      { signal: controller.signal }
    )
      .then(data => {
        if (!controller.signal.aborted) {
          setBookmarkItems(data.items);
          setBookmarks(new Set(data.items.map(item => item.questionId)));
        }
      })
      .catch(e => {
        if (!controller.signal.aborted)
          setBookmarkError(e instanceof Error ? e.message : 'Không tải được đánh dấu câu hỏi.');
      })
      .finally(() => {
        if (!controller.signal.aborted) setBookmarkLoading(false);
      });
    return () => controller.abort();
  }, [api, bank, bookmarkReload]);

  async function toggleBookmark(questionId: string, question?: Question) {
    if (!bank || bookmarkLoading || bookmarkBusy.has(questionId)) return;
    const saved = bookmarks.has(questionId);
    setBookmarkError('');
    setBookmarkBusy(previous => new Set(previous).add(questionId));
    try {
      await api(
        `/api/learning/banks/${encodeURIComponent(bank.id)}/bookmarks/${encodeURIComponent(questionId)}`,
        { method: saved ? 'DELETE' : 'PUT' }
      );
      setBookmarks(previous => {
        const next = new Set(previous);
        if (saved) next.delete(questionId);
        else next.add(questionId);
        return next;
      });
      setBookmarkItems(previous => {
        if (saved) return previous.filter(item => item.questionId !== questionId);
        return [
          {
            questionId,
            number: question?.number,
            topic: question?.topic,
            contentPreview: question?.text,
          },
          ...previous.filter(item => item.questionId !== questionId),
        ];
      });
    } catch (e) {
      setBookmarkError(e instanceof Error ? e.message : 'Không cập nhật được đánh dấu câu hỏi.');
    } finally {
      setBookmarkBusy(previous => {
        const next = new Set(previous);
        next.delete(questionId);
        return next;
      });
    }
  }

  useEffect(() => {
    const controller = new AbortController();
    if (!bank) {
      setResult(undefined);
      return () => controller.abort();
    }
    setLoading(true);
    setError('');
    const params = new URLSearchParams({ page: String(page), pageSize: '20' });
    if (topic) params.set('topic', topic);
    if (from) params.set('from', from);
    if (to) params.set('to', to);
    api<Page<Question>>(`${bankPath(bank)}/questions?${params}`, { signal: controller.signal })
      .then(data => {
        if (controller.signal.aborted) return;
        setResult(data);
        setCount(c => Math.min(Math.max(1, c), Math.max(1, data.totalCount)));
      })
      .catch(e => {
        if (!controller.signal.aborted) setError(String(e.message));
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false);
      });
    return () => controller.abort();
  }, [api, bank, topic, from, to, page]);

  async function start(ignoreFilters = false) {
    if (!bank || !onStartPractice) return;
    setError('');
    setLoading(true);
    try {
      if (ignoreFilters) {
        setTopic('');
        setFrom('');
        setTo('');
        setOnlySaved(false);
      }
      await onStartPractice({
        bankId: bank.id,
        bankVersion: bank.version,
        count,
        topic: ignoreFilters ? undefined : topic || undefined,
        from: ignoreFilters ? undefined : from ? Number(from) : undefined,
        to: ignoreFilters ? undefined : to ? Number(to) : undefined,
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Không thể bắt đầu luyện tập.');
    } finally {
      setLoading(false);
    }
  }

  function clearFilters() {
    setTopic('');
    setFrom('');
    setTo('');
    setOnlySaved(false);
    setPage(1);
  }

  const displayedQuestions = result?.items.filter(q => (!onlySaved ? true : bookmarks.has(q.id))) ?? [];

  const totalBankQuestions = banks.reduce((sum, b) => sum + b.questionCount, 0);
  const uniqueProgressList = Object.values(progressMap).filter(
    (v, i, arr) => arr.findIndex(x => x.bankId === v.bankId) === i
  );
  const totalAnsweredAll = uniqueProgressList.reduce((sum, p) => sum + p.answeredQuestions, 0);
  const totalCorrectAll = uniqueProgressList.reduce((sum, p) => sum + p.correctQuestions, 0);
  const accuracyPct = totalAnsweredAll > 0
    ? Math.min(100, Math.round((totalCorrectAll / totalAnsweredAll) * 100))
    : null;

  return (
    <section className="question-library" aria-labelledby="library-title">
      {/* Dashboard Top Header */}
      <header className="page-header learning-header">
        <div className="learning-header-copy">
          <span className="eyebrow">
            <BookOpen size={14} /> BẢNG ĐIỀU KHIỂN HỌC LUẬT · BƯỚC 1
          </span>
          <h1 id="library-title">Học luật theo cách của bạn</h1>
          <p>
            Chọn bộ câu hỏi để bắt đầu ôn tập, lọc nhanh theo chuyên đề và trực tiếp quan sát mô phỏng giao lộ 3D ngay
            trên bảng điều khiển.
          </p>
        </div>
        <div className="dash-header-cta-group">
          <button
            type="button"
            className="learning-scene-trigger"
            aria-expanded={showScene}
            onClick={() => setShowScene(value => !value)}
          >
            <span className="learning-scene-icon" aria-hidden="true">
              ↗
            </span>
            <span>
              <strong>Mô phỏng giao lộ 3D</strong>
              <small>{showScene ? 'Thu gọn khung 3D' : 'Mở khi bạn muốn khám phá'}</small>
            </span>
            <span aria-hidden="true">{showScene ? '−' : '+'}</span>
          </button>
        </div>
      </header>

      {/* Row 1: Pinterest 4-Card Bento KPI Strip */}
      <div className="bento-kpi-row" role="region" aria-label="Chỉ số tổng quan học tập">
        <div className="bento-kpi-card is-hero">
          <div className="bkc-top">
            <span>Tổng kho câu hỏi</span>
            <span className="bkc-icon-circle">
              <ArrowUpRight size={16} />
            </span>
          </div>
          <div className="bkc-value">
            {banks.length > 0 ? totalBankQuestions : '—'} <small>câu hỏi</small>
          </div>
          <div className="bkc-foot">
            <span className="bkc-badge">▲ Chuẩn sát hạch</span>
            <span>Bộ đề lý thuyết đường bộ</span>
          </div>
        </div>

        <div className="bento-kpi-card">
          <div className="bkc-top">
            <span>Độ phủ kiến thức</span>
            <span className="bkc-icon-circle">
              <Compass size={15} />
            </span>
          </div>
          <div className="bkc-mid-row">
            <div className="bkc-value">
              {totalAnsweredAll} <small>đã làm</small>
            </div>
          </div>
          <div className="bkc-foot">
            <span>{totalAnsweredAll > 0 ? 'Từ tiến độ học tập của bạn' : 'Chưa có dữ liệu tiến độ'}</span>
          </div>
        </div>

        <div className="bento-kpi-card">
          <div className="bkc-top">
            <span>Câu đã lưu &amp; Điểm liệt</span>
            <span className="bkc-icon-circle">
              <BookMarked size={15} />
            </span>
          </div>
          <div className="bkc-value">
            {bookmarks.size} <small>câu đã lưu</small>
          </div>
          <div className="bkc-foot">
            <span>Câu đã đánh dấu trong bộ đang chọn</span>
          </div>
        </div>

        <div className="bento-kpi-card is-dark-telemetry">
          <div className="bkc-top">
            <span>Studio Giao lộ 3D</span>
            <span className="bkc-live-dot" />
          </div>
          <div className="bkc-value">
            Mô phỏng <small>giao lộ 3D</small>
          </div>
          <div className="bkc-foot">
            <button type="button" className="bkc-inline-btn" onClick={() => setShowScene(v => !v)}>
              <Box size={13} /> {showScene ? 'Đang bật 3D WebGL' : 'Mở khung 3D WebGL'}
            </button>
          </div>
        </div>
      </div>

      {/* Row 2: Pinterest Asymmetric 2-Column Bento Dashboard Grid */}
      <div className="bento-dashboard-grid">
        {/* Left Main Workspace Column */}
        <div className="bento-main-col">
          {banks.length > 4 && (
            <label>
              Tìm nhanh bộ câu hỏi
              <select
                value={selected}
                onChange={e => {
                  setSelected(e.target.value);
                  setPage(1);
                  setOnlySaved(false);
                }}
              >
                <option value="">Chọn ngân hàng câu hỏi</option>
                {banks.map(b => (
                  <option key={`${b.id}/${b.version}`} value={`${b.id}/${b.version}`}>
                    {b.title} · {b.version} · {b.questionCount} câu
                  </option>
                ))}
              </select>
            </label>
          )}

          {banks.length > 0 && (
            <div className="bento-card">
              <div className="bento-card-head">
                <div>
                  <span className="bento-eyebrow">NGÂN HÀNG CÂU HỎI ĐÃ XUẤT BẢN</span>
                  <h2 className="learning-section-title" style={{ margin: 0 }}>
                    Chọn bộ câu hỏi theo hạng GPLX
                  </h2>
                </div>
              </div>
              <div className="ql-bank-grid" role="list" aria-label="Danh sách bộ câu hỏi">
                {banks.map(b => {
                  const key = `${b.id}/${b.version}`;
                  const isSelected = selected === key;
                  const prog = progressMap[key] ?? progressMap[b.id];
                  const isOfficial = b.profile.id.startsWith('gplx-');
                  const correctPct =
                    prog && prog.totalQuestions > 0 ? Math.round((prog.correctQuestions / prog.totalQuestions) * 100) : 0;
                  const wrongPct =
                    prog && prog.totalQuestions > 0 ? Math.round((prog.wrongQuestions / prog.totalQuestions) * 100) : 0;
                  return (
                    <button
                      key={key}
                      type="button"
                      role="listitem"
                      className={`ql-bank-card ${isSelected ? 'selected' : ''}`}
                      onClick={() => {
                        setSelected(key);
                        setPage(1);
                      }}
                    >
                      <div>
                        <div className="ql-bank-card-top">
                          <div className="ql-bank-badges">
                            <span className="ql-badge license">{inferLicenseLabel(b, prog)}</span>
                            <span className="ql-badge">Phiên bản {b.version}</span>
                            {isOfficial && <span className="ql-badge official">Chuẩn sát hạch</span>}
                          </div>
                        </div>
                        <h3>{b.title}</h3>
                        <div className="ql-bank-meta">
                          <span>
                            <strong>{b.questionCount}</strong> câu hỏi
                          </span>
                          <span>
                            Đề chuẩn: <strong>{b.profile.questionCount} câu</strong> /{' '}
                            {Math.ceil(b.profile.durationSeconds / 60)} phút
                          </span>
                          <span>
                            Đạt: <strong>{b.profile.passCount}/{b.profile.questionCount}</strong>
                          </span>
                        </div>
                      </div>

                      <div className="ql-bank-progress">
                        <div className="ql-progress-track" aria-hidden="true">
                          <span className="ql-progress-correct" style={{ width: `${correctPct}%` }} />
                          <span className="ql-progress-wrong" style={{ width: `${wrongPct}%` }} />
                        </div>
                        <div className="ql-progress-stats">
                          <span>
                            Đã học:{' '}
                            <strong>
                              {prog ? `${prog.answeredQuestions}/${prog.totalQuestions}` : `0/${b.questionCount}`}
                            </strong>{' '}
                            câu
                          </span>
                          <span>
                            {prog && prog.wrongQuestions > 0 ? (
                              <strong style={{ color: 'var(--danger)' }}>{prog.wrongQuestions} câu sai</strong>
                            ) : (
                              <span>Sẵn sàng ôn tập</span>
                            )}
                          </span>
                        </div>
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {loading && (
            <p role="status" className="state-box">
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: '8px' }}>
                <LoaderCircle size={16} className="spin" /> Đang tải dữ liệu câu hỏi…
              </span>
            </p>
          )}

          {error && (
            <div role="alert" className="learning-error bento-error-card">
              <div className="bec-badge">{loginRequired ? 'CHẾ ĐỘ XEM THỬ' : 'TRẠNG THÁI KẾT NỐI API LOCAL'}</div>
              <strong>{loginRequired ? 'Đăng nhập để xem câu hỏi thật' : 'Chưa thể hiển thị bộ câu hỏi'}</strong>
              <p>{error}</p>
              <div className="bec-actions">
                {loginRequired ? (
                  <button type="button" className="btn-primary" onClick={() => {
                    window.localStorage.removeItem('csgt_preview_user');
                    window.location.reload();
                  }}>
                    Đến đăng nhập
                  </button>
                ) : (
                  <>
                    <button type="button" className="btn-primary" onClick={() => setReload(value => value + 1)}>
                      <RotateCcw size={14} /> Tải lại dữ liệu
                    </button>
                    <a href="/thi" className="btn-secondary">
                      <Play size={14} /> Chuyển sang Thi thử
                    </a>
                  </>
                )}
              </div>
            </div>
          )}

          {bookmarkError && (
            <div role="alert" className="error">
              <p>{bookmarkError}</p>
              <button type="button" disabled={bookmarkLoading} onClick={() => setBookmarkReload(value => value + 1)}>
                Thử tải lại đánh dấu
              </button>
            </div>
          )}

          {!loading && !banks.length && !error && (
            <div className="state-box">
              <strong>Chưa có ngân hàng câu hỏi đã xuất bản.</strong>
              <span>Quản trị viên có thể import và xuất bản bộ câu hỏi tại mục Quản trị nội dung.</span>
            </div>
          )}
        </div>

        {/* Right Telemetry & 3D Studio Column */}
        <aside className="bento-side-col" aria-label="Mô phỏng 3D và Chỉ số sẵn sàng">
          {showScene && (
            <div className="bento-card bento-3d-shell">
              <div className="bento-card-head compact">
                <div>
                  <span className="bento-eyebrow">TRỰC QUAN HÓA GIAO THÔNG 3D</span>
                  <h2>Sa hình Ngã tư &amp; Model Xe 360°</h2>
                </div>
                <span className="bento-live-tag">
                  <Sparkles size={12} /> WebGL Live
                </span>
              </div>
              <TrafficScene variant="compact" />
            </div>
          )}

          <div className="bento-card bento-gauge-card">
            <div className="bento-card-head compact">
              <div>
                <span className="bento-eyebrow">TIẾN ĐỘ HỌC TẬP</span>
                <h2>Tỷ lệ trả lời đúng</h2>
              </div>
            </div>

            <div className="pinterest-gauge-wrap">
              <svg viewBox="0 0 220 125" className="pinterest-gauge-svg" aria-hidden="true">
                <defs>
                  <linearGradient id="emeraldGauge" x1="0" y1="0" x2="1" y2="0">
                    <stop offset="0%" stopColor="#0b7568" />
                    <stop offset="65%" stopColor="#14b886" />
                    <stop offset="100%" stopColor="#e68a67" />
                  </linearGradient>
                </defs>
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
                  stroke="url(#emeraldGauge)"
                  strokeWidth="20"
                  strokeLinecap="round"
                  strokeDasharray="276"
                  strokeDashoffset={Math.round(276 * (1 - (accuracyPct ?? 0) / 100))}
                />
              </svg>
              <div className="pinterest-gauge-center">
                <strong>{accuracyPct === null ? '—' : `${accuracyPct}%`}</strong>
                <span>{accuracyPct === null ? 'Chưa có dữ liệu' : `${totalCorrectAll}/${totalAnsweredAll} câu đúng`}</span>
              </div>
            </div>

            <div className="bento-checklist">
              <div className="bcl-item">
                <CheckCircle2 size={15} className="bcl-icon ok" />
                <div>
                  <strong>Ôn theo bộ câu hỏi đã xuất bản</strong>
                  <small>Chọn ngân hàng câu hỏi để xem nội dung và tiến độ của bạn.</small>
                </div>
              </div>
              <div className="bcl-item">
                <Layers size={15} className="bcl-icon accent" />
                <div>
                  <strong>Mở mô phỏng giao lộ khi cần</strong>
                  <small>Quan sát tình huống giao thông trong khung 3D.</small>
                </div>
              </div>
            </div>
          </div>
        </aside>
      </div>

      {/* Selected Bank Workspace (Filters, Practice Box, Question List) */}
      {bank && (
        <>
          <div className="ql-workspace-header">
            <div>
              <span className="eyebrow">ĐANG XEM BỘ CÂU HỎI</span>
              <h2 style={{ margin: '4px 0 4px', fontSize: '18px' }}>{bank.title}</h2>
              <p className="muted" style={{ margin: 0 }}>
                {bank.sourceDescription} ·{' '}
                <a href={bank.sourceUrl} target="_blank" rel="noreferrer">
                  Nguồn dữ liệu <ExternalLink size={12} />
                </a>
              </p>
            </div>
            <div className="ql-view-tabs" role="tablist" aria-label="Chế độ xem câu hỏi">
              <button
                type="button"
                role="tab"
                aria-selected={!onlySaved}
                className={!onlySaved ? 'active' : ''}
                onClick={() => setOnlySaved(false)}
              >
                Tất cả câu hỏi ({result?.totalCount ?? bank.questionCount})
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={onlySaved}
                className={onlySaved ? 'active' : ''}
                onClick={() => setOnlySaved(true)}
              >
                <BookMarked size={14} style={{ verticalAlign: '-2px', marginRight: '5px' }} />
                Câu đã lưu ({bookmarks.size})
              </button>
            </div>
          </div>

          <div className="ql-control-grid">
            <div className="ql-filter-box">
              <h2>
                <Filter size={16} /> Bộ lọc câu hỏi trên trang
              </h2>
              <div className="ql-filter-inputs filters">
                <label>
                  Chủ đề
                  <input
                    placeholder="VD: Khái niệm, Biển báo, Sa hình…"
                    value={topic}
                    onChange={e => {
                      setTopic(e.target.value);
                      setPage(1);
                    }}
                  />
                </label>
                <label>
                  Từ câu
                  <input
                    type="number"
                    min="1"
                    placeholder="1"
                    value={from}
                    onChange={e => {
                      setFrom(e.target.value);
                      setPage(1);
                    }}
                  />
                </label>
                <label>
                  Đến câu
                  <input
                    type="number"
                    min="1"
                    placeholder={String(bank.questionCount)}
                    value={to}
                    onChange={e => {
                      setTo(e.target.value);
                      setPage(1);
                    }}
                  />
                </label>
              </div>
              <div className="ql-filter-actions">
                <span>
                  Đang khớp: <strong>{result?.totalCount ?? 0}</strong> câu hỏi
                  {bookmarks.size > 0 ? ` · Đã đánh dấu ${bookmarks.size} câu` : ''}
                </span>
                {hasActiveFilter && (
                  <button type="button" className="btn-secondary" onClick={clearFilters}>
                    <RotateCcw size={14} /> Xóa bộ lọc
                  </button>
                )}
              </div>
            </div>

            <div className="ql-practice-box">
              <h2>
                <Play size={16} /> Luyện bộ này
              </h2>
              {official ? (
                <>
                  <p style={{ fontSize: '13.5px', marginBottom: '12px' }}>
                    Đây là bộ câu hỏi thi thử theo quy tắc sát hạch chuẩn ({bank.profile.questionCount} câu /{' '}
                    {Math.ceil(bank.profile.durationSeconds / 60)} phút, đạt từ {bank.profile.passCount} câu). Chọn đề
                    chuẩn tương ứng trong mục <strong>Thi thử</strong> để giữ đúng cấu trúc phân bổ và thời gian.
                  </p>
                  <a
                    className="btn-primary"
                    href={`/thi?bank=${encodeURIComponent(bank.id)}&version=${encodeURIComponent(bank.version)}`}
                  >
                    Mở trang Thi thử đề chuẩn <Play size={15} />
                  </a>
                </>
              ) : (
                <>
                  <p style={{ fontSize: '13px', margin: '0 0 10px', color: 'var(--text-secondary)' }}>
                    Chọn số lượng câu muốn luyện tập để chuyển sang bước tạo đề và tính giờ:
                  </p>
                  <div className="ql-practice-controls">
                    <label>
                      Số câu luyện
                      <input
                        type="number"
                        min="1"
                        max={result?.totalCount || 1}
                        value={count}
                        onChange={e => setCount(Number(e.target.value))}
                      />
                    </label>
                    <button
                      type="button"
                      className="btn-primary"
                      disabled={
                        loading ||
                        !onStartPractice ||
                        !Number.isInteger(count) ||
                        count < 1 ||
                        count > (result?.totalCount ?? 0)
                      }
                      onClick={() => void start(false)}
                    >
                      Bắt đầu luyện tập
                    </button>
                  </div>
                  {hasActiveFilter && (
                    <div className="ql-filter-warning" role="note">
                      <ShieldAlert size={15} style={{ verticalAlign: '-3px', marginRight: '6px' }} />
                      <strong>Lưu ý trước khi bắt đầu:</strong> Bộ lọc đang bật chỉ áp dụng cho danh sách đọc câu hỏi
                      bên dưới. API luyện thi hiện lấy câu hỏi từ toàn bộ ngân hàng đã chọn.
                      <div className="ql-filter-warning-actions">
                        <button
                          type="button"
                          className="btn-secondary"
                          disabled={loading || !onStartPractice}
                          onClick={() => void start(true)}
                        >
                          Xóa bộ lọc &amp; Luyện {count} câu toàn bộ ngân hàng
                        </button>
                      </div>
                    </div>
                  )}
                </>
              )}
              {!onStartPractice && (
                <p className="muted">
                  Chức năng làm bài sẽ được nối với Practice API khi module luyện thi được tích hợp.
                </p>
              )}
            </div>
          </div>
        </>
      )}

      {bank && onlySaved && bookmarkItems.length > 0 && displayedQuestions.length === 0 && (
        <div className="alert-info">
          <strong>Danh sách {bookmarkItems.length} câu đã lưu trong bộ này:</strong>
          <p style={{ margin: '6px 0 10px', fontSize: '13px' }}>
            Các câu bạn đã lưu nằm ở các trang khác nhau. Bấm vào câu bất kỳ để nhảy ngay tới câu đó:
          </p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
            {bookmarkItems.map(item => (
              <button
                key={item.questionId}
                type="button"
                className="btn-secondary"
                onClick={() => {
                  if (item.number) {
                    setFrom(String(item.number));
                    setTo(String(item.number));
                    setOnlySaved(false);
                    setPage(1);
                  }
                }}
              >
                Câu {item.number ?? '—'}: {item.contentPreview?.slice(0, 42) || 'Xem câu hỏi'}…
              </button>
            ))}
          </div>
        </div>
      )}

      {result && (
        <>
          <p className="muted" style={{ fontWeight: 600 }}>
            {result.totalCount} câu phù hợp{' '}
            {onlySaved ? `(Đang lọc ${displayedQuestions.length} câu đã lưu ở trang này)` : `· Trang ${page}`}
          </p>

          {onlySaved && bookmarks.size === 0 && (
            <div className="state-box">
              <strong>Bạn chưa lưu (đánh dấu) câu hỏi nào trong bộ này.</strong>
              <span>Bấm nút &ldquo;Đánh dấu câu hỏi&rdquo; ở câu bất kỳ để lưu lại ôn tập trước khi thi.</span>
            </div>
          )}

          {displayedQuestions.map(q => (
            <article key={q.id} className="ql-question-card">
              <div className="ql-question-top">
                <div className="ql-question-meta">
                  <span className="ql-question-num">Câu {q.number}</span>
                  <span className="ql-question-topic">
                    {q.topic} · Câu {q.number}
                  </span>
                </div>
                <button
                  type="button"
                  className="ql-bookmark-btn"
                  aria-pressed={bookmarks.has(q.id)}
                  disabled={bookmarkLoading || bookmarkBusy.has(q.id)}
                  onClick={() => void toggleBookmark(q.id, q)}
                  aria-label={`${bookmarks.has(q.id) ? 'Bỏ đánh dấu' : 'Đánh dấu'} câu ${q.number}`}
                >
                  <BookMarked size={15} />
                  {bookmarkBusy.has(q.id) ? 'Đang lưu…' : bookmarks.has(q.id) ? 'Đã đánh dấu' : 'Đánh dấu câu hỏi'}
                </button>
              </div>

              <h2 className="ql-question-title">{q.text}</h2>

              {q.assets.length > 0 && (
                <div className="ql-question-image">
                  {q.assets.map(a => (
                    <img key={a.id} src={a.url} alt={a.altText} loading="lazy" referrerPolicy="no-referrer" />
                  ))}
                </div>
              )}

              <ol className="ql-options-list">
                {q.options.map((o, idx) => (
                  <li key={o.id} className="ql-option-item">
                    <span className="ql-option-letter">{String.fromCharCode(65 + idx)}</span>
                    <span>{o.text}</span>
                  </li>
                ))}
              </ol>

              <div className="ql-question-footer">
                <span className="muted">Mã câu: {q.number}</span>
                <a href={q.sourceUrl} target="_blank" rel="noreferrer">
                  Nguồn câu hỏi <ExternalLink size={13} />
                </a>
              </div>
            </article>
          ))}

          <div className="ql-pager filters">
            <button
              type="button"
              className="btn-secondary"
              disabled={page <= 1 || loading}
              onClick={() => setPage(p => p - 1)}
            >
              Trang trước
            </button>
            <span>
              <strong>Trang {page}</strong> / {Math.max(1, Math.ceil(result.totalCount / 20))}
            </span>
            <button
              type="button"
              className="btn-secondary"
              disabled={page * 20 >= result.totalCount || loading}
              onClick={() => setPage(p => p + 1)}
            >
              Trang sau
            </button>
          </div>
        </>
      )}
    </section>
  );
}
