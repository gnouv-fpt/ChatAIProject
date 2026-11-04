import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import {
  AlertTriangle,
  Bell,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  ClipboardCheck,
  Clock,
  FileCheck2,
  Grid,
  History,
  ListChecks,
  LoaderCircle,
  Play,
  RotateCcw,
  Send,
  Sliders,
  X,
} from 'lucide-react';
import { api } from '../../api';
import type { Bank } from '../questions/content-api';
import './exam.css';
import { Modal } from '../../components/Modal';
import { TrafficScene } from '../../components/TrafficScene';

type ExamTemplate = {
  id: string;
  examCode: string;
  version: number;
  title: string;
  durationMinutes: number;
  passingScore: number;
  isPublished: boolean;
  questionIds: string[];
};

type ExamOption = { id: string; text: string };
type ExamAsset = { id: string; url: string; altText: string };
type ExamQuestion = { id: string; text: string; options: ExamOption[]; assets?: ExamAsset[] | null };

type CustomExamView = {
  examId: string;
  bankVersion: string;
  deadlineUtc: string;
  revision: number;
  status: 'Active' | 'Submitted' | 'Expired';
  questions: ExamQuestion[];
  answers: Record<string, string>;
  bankId?: string;
  passingScore: number;
  failOnCriticalWrong: boolean;
  attemptId?: string | null;
};

type ExamScore = {
  attemptId: string;
  examId: string;
  correct: number;
  total: number;
  submittedAtUtc: string;
};

type ExamNotification = {
  eventId: string;
  examId: string;
  correct: number;
  total: number;
  occurredAtUtc: string;
};

export function ExamPage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();

  const [banks, setBanks] = useState<Bank[]>([]);
  const [templates, setTemplates] = useState<ExamTemplate[]>([]);
  const [notifications, setNotifications] = useState<ExamNotification[]>([]);
  const [loadingSetup, setLoadingSetup] = useState(true);
  const [setupError, setSetupError] = useState('');
  const [showScene, setShowScene] = useState(true);

  // Mode: 'template' (Thi thử theo đề chuẩn) vs 'custom' (Luyện tập theo số câu)
  const initialMode = searchParams.get('bank') ? 'custom' : 'template';
  const [mode, setMode] = useState<'template' | 'custom'>(initialMode);

  const [selectedTemplateKey, setSelectedTemplateKey] = useState('');
  const [selectedBankKey, setSelectedBankKey] = useState('');
  const [customCount, setCustomCount] = useState<number>(Number(searchParams.get('count')) || 10);
  const [customMinutes, setCustomMinutes] = useState<number>(20);
  const [confirmedConfig, setConfirmedConfig] = useState(false);
  const [resumeId, setResumeId] = useState('');

  // Active exam state
  const [exam, setExam] = useState<CustomExamView | null>(null);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [viewAllQuestions, setViewAllQuestions] = useState(false);
  const [saveState, setSaveState] = useState<'idle' | 'saving' | 'saved' | 'error'>('idle');
  const [saveMessage, setSaveMessage] = useState('Tự động lưu trên máy chủ');
  const [starting, setStarting] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [showConfirmSubmit, setShowConfirmSubmit] = useState(false);
  const [showMobilePalette, setShowMobilePalette] = useState(false);
  const [remainingSeconds, setRemainingSeconds] = useState<number>(0);
  const pageRef = useRef<HTMLElement>(null);

  useEffect(() => {
    pageRef.current?.scrollTo({ top: 0, behavior: 'instant' });
  }, [exam?.examId]);

  async function loadSetupData() {
    setLoadingSetup(true);
    setSetupError('');
    try {
      const [bankList, templateList, notifList] = await Promise.all([
        api<Bank[]>('/question-banks'),
        api<ExamTemplate[]>('/exam-templates').catch(() => [] as ExamTemplate[]),
        api<ExamNotification[]>('/exam-notifications').catch(() => [] as ExamNotification[]),
      ]);
      setBanks(bankList);
      setTemplates(templateList);
      setNotifications(notifList);

      const qBank = searchParams.get('bank');
      const qVersion = searchParams.get('version');
      const qCount = searchParams.get('count');

      if (qBank) {
        const matchedBank =
          bankList.find(b => b.id === qBank && (!qVersion || b.version === qVersion)) ??
          bankList.find(b => b.id === qBank);
        if (matchedBank) {
          setSelectedBankKey(`${matchedBank.id}/${matchedBank.version}`);
          const isOfficial = matchedBank.profile.id.startsWith('gplx-');
          if (isOfficial && !qCount && templateList.length > 0) {
            setMode('template');
          } else {
            setMode('custom');
            setCustomCount(qCount ? Number(qCount) : matchedBank.profile.questionCount);
            setCustomMinutes(Math.max(1, Math.ceil(matchedBank.profile.durationSeconds / 60)));
          }
        }
      } else if (bankList.length > 0) {
        const firstBank = bankList[0];
        setSelectedBankKey(`${firstBank.id}/${firstBank.version}`);
        setCustomCount(firstBank.profile.questionCount);
        setCustomMinutes(Math.max(1, Math.ceil(firstBank.profile.durationSeconds / 60)));
      }

      if (templateList.length > 0) {
        setSelectedTemplateKey(`${templateList[0].examCode}/${templateList[0].version}`);
      } else if (bankList.length > 0) {
        setMode('custom');
      }
    } catch (e) {
      setSetupError(e instanceof Error ? e.message : 'Không thể tải cấu hình đề thi.');
    } finally {
      setLoadingSetup(false);
    }
  }

  useEffect(() => {
    void loadSetupData();
  }, []);

  const selectedTemplate = useMemo(
    () => templates.find(t => `${t.examCode}/${t.version}` === selectedTemplateKey),
    [templates, selectedTemplateKey]
  );

  const selectedBank = useMemo(
    () => banks.find(b => `${b.id}/${b.version}` === selectedBankKey),
    [banks, selectedBankKey]
  );

  const isSelectedBankOfficial = selectedBank?.profile.id.startsWith('gplx-') ?? false;

  const validCustomConfig = Boolean(selectedBank) && Number.isInteger(customCount)
    && customCount >= 1 && customCount <= Math.min(100, selectedBank?.questionCount ?? 0)
    && Number.isInteger(customMinutes) && customMinutes >= 1 && customMinutes <= 180;

  useEffect(() => { setConfirmedConfig(false); }, [mode, selectedTemplateKey, selectedBankKey, customCount, customMinutes]);

  // Countdown timer & auto-submit on deadline
  useEffect(() => {
    if (!exam) return;
    const updateClock = () => {
      const left = Math.max(0, Math.ceil((new Date(exam.deadlineUtc).getTime() - Date.now()) / 1000));
      setRemainingSeconds(left);
      if (left === 0 && exam.status === 'Active' && !submitting) {
        void handleFinalSubmit();
      }
    };
    updateClock();
    const timerId = window.setInterval(updateClock, 1000);
    return () => window.clearInterval(timerId);
  }, [exam, submitting]);

  // Poll notifications periodically when on setup screen
  useEffect(() => {
    if (exam) return;
    const timer = window.setInterval(() => {
      api<ExamNotification[]>('/exam-notifications')
        .then(setNotifications)
        .catch(() => {});
    }, 12000);
    return () => window.clearInterval(timer);
  }, [exam]);

  function handleBankSelectChange(value: string) {
    setSelectedBankKey(value);
    const b = banks.find(item => `${item.id}/${item.version}` === value);
    if (b) {
      setCustomCount(b.profile.questionCount);
      setCustomMinutes(Math.max(1, Math.ceil(b.profile.durationSeconds / 60)));
    }
  }

  async function startSelectedExam() {
    if (!confirmedConfig || starting) return;
    setStarting(true);
    setSetupError('');
    try {
      if (mode === 'template') {
        if (!selectedTemplate) throw new Error('Vui lòng chọn một đề thi chuẩn.');
        const created = await api<CustomExamView>('/custom-exams/from-template', {
          method: 'POST',
          body: JSON.stringify({ examCode: selectedTemplate.examCode, version: selectedTemplate.version }),
        });
        setExam(created);
        setCurrentIndex(0);
        setSaveState('saved');
        setSaveMessage('Đề chuẩn đã sẵn sàng · Lưu tự động');
      } else {
        if (!selectedBank) throw new Error('Vui lòng chọn ngân hàng câu hỏi.');
        if (!validCustomConfig) throw new Error('Kiểm tra lại số câu hỏi và thời gian làm bài.');
        const created = await api<CustomExamView>('/custom-exams', {
          method: 'POST',
          body: JSON.stringify({
            categoryId: selectedBank.id,
            bankVersion: selectedBank.version,
            questionCount: Number(customCount),
            durationMinutes: Number(customMinutes),
          }),
        });
        setExam(created);
        setCurrentIndex(0);
        setSaveState('saved');
        setSaveMessage('Đề luyện tập đã tạo · Lưu tự động');
      }
    } catch (e) {
      setSetupError(e instanceof Error ? e.message : 'Không thể khởi tạo bài thi.');
    } finally {
      setStarting(false);
    }
  }

  async function resumeExamById(e: React.FormEvent) {
    e.preventDefault();
    const id = resumeId.trim();
    if (!id || starting) return;
    setStarting(true);
    setSetupError('');
    try {
      const loaded = await api<CustomExamView>(`/custom-exams/${encodeURIComponent(id)}`);
      setExam(loaded);
      setCurrentIndex(0);
      setSaveState('saved');
      setSaveMessage('Đã khôi phục phiên làm bài');
    } catch (err) {
      setSetupError(err instanceof Error ? err.message : 'Không tìm thấy mã đề hoặc đề đã hết hạn.');
    } finally {
      setStarting(false);
    }
  }

  async function selectAnswer(questionId: string, optionId: string) {
    if (!exam || exam.status !== 'Active' || saveState === 'saving' || submitting) return;
    setSaveState('saving');
    setSaveMessage('Đang lưu câu trả lời…');
    try {
      const updated = await api<CustomExamView>(
        `/custom-exams/${exam.examId}/answers/${encodeURIComponent(questionId)}`,
        {
          method: 'PUT',
          body: JSON.stringify({ optionId, revision: exam.revision }),
        }
      );
      setExam(updated);
      setSaveState('saved');
      setSaveMessage('Đã lưu tự động');
    } catch (e) {
      setSaveState('error');
      setSaveMessage(e instanceof Error ? e.message : 'Chưa lưu được đáp án');
      try {
        const refreshed = await api<CustomExamView>(`/custom-exams/${exam.examId}`);
        setExam(refreshed);
      } catch {
        /* keep error state */
      }
    }
  }

  async function handleFinalSubmit() {
    if (!exam || submitting) return;
    setSubmitting(true);
    setShowConfirmSubmit(false);
    setSaveState('saving');
    setSaveMessage('Đang nộp bài và chấm điểm…');
    try {
      const score = await api<ExamScore>(`/custom-exams/${exam.examId}/submit`, { method: 'POST' });
      setExam(prev => (prev ? { ...prev, status: 'Submitted', attemptId: score.attemptId } : prev));
      navigate(`/ket-qua/${score.attemptId}`);
    } catch (e) {
      setSaveState('error');
      setSaveMessage(e instanceof Error ? e.message : 'Không thể nộp bài. Vui lòng thử lại.');
    } finally {
      setSubmitting(false);
    }
  }

  const formatTimer = (sec: number) => `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`;

  if (exam) {
    const totalQuestions = exam.questions.length;
    const answeredCount = exam.questions.filter(q => Boolean(exam.answers[q.id])).length;
    const unansweredIndices = exam.questions
      .map((q, idx) => (!exam.answers[q.id] ? idx + 1 : null))
      .filter((v): v is number => v !== null);
    const activeQuestion = exam.questions[currentIndex] ?? exam.questions[0];

    return (
      <main ref={pageRef} className="exam-page">
        <div className="exam-container">
          {/* Sticky Top Bar */}
          <header className="exam-active-bar" aria-label="Thanh trạng thái làm bài">
            <div className="exam-timer-group">
              <div className={`exam-timer-badge ${remainingSeconds <= 120 ? 'urgent' : ''}`} role="timer" aria-live="off">
                <Clock size={18} />
                <span>{formatTimer(remainingSeconds)}</span>
              </div>

              <div className={`exam-save-indicator ${saveState === 'saved' ? 'saved' : saveState === 'error' ? 'error' : ''}`} role="status">
                {saveState === 'saving' ? <LoaderCircle size={14} className="spin" /> : saveState === 'error' ? <AlertTriangle size={14} /> : <CheckCircle2 size={14} />}
                <span>{saveMessage}</span>
              </div>

              <span style={{ fontSize: '13.5px', fontWeight: 700, color: 'var(--text-secondary)' }}>
                Đã làm: <strong style={{ color: 'var(--text-primary)' }}>{answeredCount}/{totalQuestions}</strong> câu
              </span>
            </div>

            <div className="exam-bar-actions">
              <button
                type="button"
                className="btn-secondary"
                onClick={() => setViewAllQuestions(v => !v)}
              >
                <ListChecks size={15} />
                {viewAllQuestions ? 'Xem từng câu' : 'Xem toàn bộ đề'}
              </button>

              <button
                type="button"
                className="btn-secondary exam-mobile-palette-btn"
                onClick={() => setShowMobilePalette(true)}
              >
                <Grid size={15} /> Bảng câu ({answeredCount}/{totalQuestions})
              </button>

              {exam.status === 'Submitted' && exam.attemptId ? (
                <button
                  type="button"
                  className="btn-primary"
                  onClick={() => navigate(`/ket-qua/${exam.attemptId}`)}
                >
                  Xem kết quả bài làm
                </button>
              ) : (
                <button
                  type="button"
                  className="btn-primary"
                  disabled={submitting || saveState === 'saving'}
                  onClick={() => setShowConfirmSubmit(true)}
                >
                  <Send size={15} /> Nộp bài
                </button>
              )}
            </div>
          </header>

          {/* Target Info Banner */}
          <div className="alert-info" style={{ display: 'flex', justifyContent: 'space-between', flexWrap: 'wrap', gap: '8px', marginBottom: '18px' }}>
            <span>
              <strong>Mục tiêu đạt:</strong> Đúng tối thiểu <strong>{exam.passingScore}/{totalQuestions}</strong> câu
              {exam.failOnCriticalWrong ? ' và không trả lời sai câu điểm liệt.' : '.'}
            </span>
            <span className="muted" style={{ fontSize: '12px' }}>
              Mã phiên đề: <code>{exam.examId}</code>
            </span>
          </div>

          <div className="exam-active-grid">
            {/* Main Question Area */}
            <div>
              {viewAllQuestions ? (
                exam.questions.map((q, idx) => {
                  const chosen = exam.answers[q.id];
                  return (
                    <article
                      key={q.id}
                      id={`exam-q-${idx}`}
                      className="exam-question-stage"
                      style={{ marginBottom: '18px' }}
                    >
                      <div className="exam-question-stage-header">
                        <span className="exam-q-badge">
                          Câu {idx + 1} / {totalQuestions}
                        </span>
                        <span className={`exam-q-status-tag ${chosen ? 'answered' : 'unanswered'}`}>
                          {chosen ? 'Đã trả lời' : 'Chưa trả lời'}
                        </span>
                      </div>

                      <h2 className="exam-question-text">{q.text}</h2>

                      {q.assets && q.assets.length > 0 && (
                        <div className="exam-question-assets">
                          {q.assets.map(asset => (
                            <img key={asset.id} src={asset.url} alt={asset.altText} referrerPolicy="no-referrer" />
                          ))}
                        </div>
                      )}

                      <div className="exam-options-group" role="radiogroup" aria-label={`Câu ${idx + 1}`}>
                        {q.options.map((opt, optIdx) => {
                          const isSelected = chosen === opt.id;
                          return (
                            <label key={opt.id} className={`exam-option-card ${isSelected ? 'selected' : ''}`}>
                              <input
                                type="radio"
                                name={`q-${q.id}`}
                                value={opt.id}
                                checked={isSelected}
                                disabled={exam.status !== 'Active' || saveState === 'saving' || submitting}
                                onChange={() => void selectAnswer(q.id, opt.id)}
                              />
                              <span className="exam-option-letter">{String.fromCharCode(65 + optIdx)}</span>
                              <span>{opt.text}</span>
                            </label>
                          );
                        })}
                      </div>
                    </article>
                  );
                })
              ) : (
                activeQuestion && (
                  <article className="exam-question-stage">
                    <div className="exam-question-stage-header">
                      <span className="exam-q-badge">
                        Câu {currentIndex + 1} / {totalQuestions}
                      </span>
                      <span
                        className={`exam-q-status-tag ${exam.answers[activeQuestion.id] ? 'answered' : 'unanswered'}`}
                      >
                        {exam.answers[activeQuestion.id] ? 'Đã chọn đáp án' : 'Chưa trả lời'}
                      </span>
                    </div>

                    <h2 className="exam-question-text">{activeQuestion.text}</h2>

                    {activeQuestion.assets && activeQuestion.assets.length > 0 && (
                      <div className="exam-question-assets">
                        {activeQuestion.assets.map(asset => (
                          <img key={asset.id} src={asset.url} alt={asset.altText} referrerPolicy="no-referrer" />
                        ))}
                      </div>
                    )}

                    <div className="exam-options-group" role="radiogroup" aria-label={`Câu ${currentIndex + 1}`}>
                      {activeQuestion.options.map((opt, optIdx) => {
                        const isSelected = exam.answers[activeQuestion.id] === opt.id;
                        return (
                          <label key={opt.id} className={`exam-option-card ${isSelected ? 'selected' : ''}`}>
                            <input
                              type="radio"
                              name={`q-${activeQuestion.id}`}
                              value={opt.id}
                              checked={isSelected}
                              disabled={exam.status !== 'Active' || saveState === 'saving' || submitting}
                              onChange={() => void selectAnswer(activeQuestion.id, opt.id)}
                            />
                            <span className="exam-option-letter">{String.fromCharCode(65 + optIdx)}</span>
                            <span>{opt.text}</span>
                          </label>
                        );
                      })}
                    </div>

                    <div className="exam-question-nav">
                      <button
                        type="button"
                        className="btn-secondary"
                        disabled={currentIndex <= 0}
                        onClick={() => setCurrentIndex(i => Math.max(0, i - 1))}
                      >
                        <ChevronLeft size={16} /> Câu trước
                      </button>

                      <span className="muted">
                        Câu {currentIndex + 1} trên {totalQuestions}
                      </span>

                      {currentIndex < totalQuestions - 1 ? (
                        <button
                          type="button"
                          className="btn-primary"
                          onClick={() => setCurrentIndex(i => Math.min(totalQuestions - 1, i + 1))}
                        >
                          Câu tiếp theo <ChevronRight size={16} />
                        </button>
                      ) : (
                        <button
                          type="button"
                          className="btn-primary"
                          onClick={() => setShowConfirmSubmit(true)}
                        >
                          Kiểm tra & Nộp bài <Send size={15} />
                        </button>
                      )}
                    </div>
                  </article>
                )
              )}
            </div>

            {/* Desktop Question Palette */}
            <aside className="exam-palette-panel desktop-only" aria-label="Bảng danh sách câu hỏi">
              <h3>
                <span>Bảng số câu hỏi</span>
                <small>{answeredCount}/{totalQuestions}</small>
              </h3>
              <div className="exam-palette-legend">
                <span>
                  <i className="palette-dot answered" /> Đã trả lời ({answeredCount})
                </span>
                <span>
                  <i className="palette-dot unanswered" /> Chưa trả lời ({unansweredIndices.length})
                </span>
                <span>
                  <i className="palette-dot current" /> Đang xem
                </span>
              </div>
              <div className="exam-palette-grid">
                {exam.questions.map((q, idx) => {
                  const isAnswered = Boolean(exam.answers[q.id]);
                  const isCurrent = !viewAllQuestions && idx === currentIndex;
                  return (
                    <button
                      key={q.id}
                      type="button"
                      className={`exam-palette-btn ${isAnswered ? 'answered' : ''} ${isCurrent ? 'current' : ''}`}
                      aria-current={isCurrent ? 'step' : undefined}
                      aria-label={`Câu ${idx + 1}: ${isAnswered ? 'Đã trả lời' : 'Chưa trả lời'}`}
                      onClick={() => {
                        setCurrentIndex(idx);
                        if (viewAllQuestions) {
                          document.getElementById(`exam-q-${idx}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
                        }
                      }}
                    >
                      {idx + 1}
                    </button>
                  );
                })}
              </div>

              <div style={{ marginTop: '16px', paddingTop: '14px', borderTop: '1px solid var(--border-light)', display: 'grid', gap: '8px' }}>
                <button
                  type="button"
                  className="btn-primary"
                  style={{ width: '100%' }}
                  disabled={submitting || saveState === 'saving'}
                  onClick={() => setShowConfirmSubmit(true)}
                >
                  <Send size={15} /> Nộp bài ({answeredCount}/{totalQuestions})
                </button>
                <button
                  type="button"
                  className="btn-secondary"
                  style={{ width: '100%' }}
                  onClick={() => setExam(null)}
                >
                  <RotateCcw size={14} /> Đổi đề khác
                </button>
              </div>
            </aside>
          </div>
        </div>

        {/* Mobile Question Palette Drawer */}
        {showMobilePalette && (
          <Modal className="exam-modal-backdrop" label="Danh sách câu hỏi" onClose={() => setShowMobilePalette(false)}>
            <div
              className="exam-modal-card"
              style={{ alignSelf: 'end', maxWidth: '100%', borderRadius: '18px 18px 0 0' }}
              onClick={e => e.stopPropagation()}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                <h2 style={{ margin: 0, fontSize: '17px' }}>
                  Bảng số câu ({answeredCount}/{totalQuestions} đã trả lời)
                </h2>
                <button type="button" className="icon-button" aria-label="Đóng bảng câu hỏi" onClick={() => setShowMobilePalette(false)}>
                  <X size={18} />
                </button>
              </div>
              <div className="exam-palette-legend">
                <span>
                  <i className="palette-dot answered" /> Đã trả lời ({answeredCount})
                </span>
                <span>
                  <i className="palette-dot unanswered" /> Bỏ trống ({unansweredIndices.length})
                </span>
                <span>
                  <i className="palette-dot current" /> Đang xem
                </span>
              </div>
              <div className="exam-palette-grid">
                {exam.questions.map((q, idx) => {
                  const isAnswered = Boolean(exam.answers[q.id]);
                  const isCurrent = idx === currentIndex;
                  return (
                    <button
                      key={q.id}
                      type="button"
                      className={`exam-palette-btn ${isAnswered ? 'answered' : ''} ${isCurrent ? 'current' : ''}`}
                      aria-current={isCurrent ? 'step' : undefined}
                      onClick={() => {
                        setCurrentIndex(idx);
                        setShowMobilePalette(false);
                        if (viewAllQuestions) {
                          document.getElementById(`exam-q-${idx}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
                        }
                      }}
                    >
                      {idx + 1}
                    </button>
                  );
                })}
              </div>
            </div>
          </Modal>
        )}

        {/* Submit Confirmation Modal */}
        {showConfirmSubmit && (
          <Modal className="exam-modal-backdrop" label="Xác nhận nộp bài" onClose={() => setShowConfirmSubmit(false)}>
            <div className="exam-modal-card">
              <h2 id="submit-confirm-title">
                <ClipboardCheck size={22} color="var(--primary)" /> Xác nhận nộp bài
              </h2>
              <p style={{ margin: '0 0 12px', fontSize: '14.5px' }}>
                Bạn đã trả lời <strong>{answeredCount}</strong> trên tổng số <strong>{totalQuestions}</strong> câu hỏi.
              </p>

              {unansweredIndices.length > 0 ? (
                <div className="alert-warning">
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontWeight: 700 }}>
                    <AlertTriangle size={16} /> Còn {unansweredIndices.length} câu đang bỏ trống chưa trả lời:
                  </div>
                  <p style={{ margin: '6px 0 8px', fontSize: '12.5px' }}>
                    Bấm vào số câu bên dưới nếu bạn muốn quay lại bổ sung trước khi nộp:
                  </p>
                  <div className="exam-blank-pills">
                    {unansweredIndices.map(num => (
                      <button
                        key={num}
                        type="button"
                        className="exam-blank-pill"
                        onClick={() => {
                          setCurrentIndex(num - 1);
                          setViewAllQuestions(false);
                          setShowConfirmSubmit(false);
                        }}
                      >
                        Câu {num}
                      </button>
                    ))}
                  </div>
                </div>
              ) : (
                <div className="alert-success">
                  <strong>Hoàn tất 100% câu hỏi!</strong> Bạn đã chọn đáp án cho tất cả {totalQuestions} câu trong đề.
                </div>
              )}

              <div className="exam-modal-actions">
                <button
                  type="button"
                  className="btn-secondary"
                  disabled={submitting}
                  onClick={() => setShowConfirmSubmit(false)}
                >
                  Quay lại làm tiếp
                </button>
                <button
                  type="button"
                  className="btn-primary"
                  disabled={submitting}
                  onClick={() => void handleFinalSubmit()}
                >
                  {submitting ? 'Đang chấm bài…' : 'Xác nhận nộp bài ngay'}
                </button>
              </div>
            </div>
          </Modal>
        )}
      </main>
    );
  }

  // Setup Screen (Chọn đề & Xác nhận cấu hình)
  return (
    <main ref={pageRef} className="exam-page">
      <div className="exam-container">
        <header className="page-header exam-intro">
          <div>
            <span className="eyebrow"><FileCheck2 size={14} /> LUYỆN THI GIAO THÔNG</span>
            <h1>Chọn bài thi phù hợp với bạn</h1>
            <p>Thi thử theo đề chuẩn hoặc luyện theo số câu. Bài làm được lưu trong khi bạn trả lời.</p>
          </div>
          <button type="button" className="learning-scene-trigger" aria-expanded={showScene} onClick={() => setShowScene(value => !value)}>
            <span className="learning-scene-icon" aria-hidden="true">↗</span>
            <span><strong>Mô phỏng giao lộ 3D</strong><small>{showScene ? 'Thu gọn mô phỏng' : 'Mở khi bạn muốn khám phá'}</small></span>
            <span aria-hidden="true">{showScene ? '−' : '+'}</span>
          </button>
        </header>

        {/* Pinterest 4-Card Bento KPI Row for Exam Command Center */}
        <div className="bento-kpi-row" role="region" aria-label="Thông số sát hạch tổng quan">
          <div className="bento-kpi-card is-hero">
            <div className="bkc-top">
              <span>Hình thức sát hạch</span>
              <span className="bkc-icon-circle"><FileCheck2 size={15} /></span>
            </div>
            <div className="bkc-value">2 Chế độ <small>chuẩn</small></div>
            <div className="bkc-foot">
              <span className="bkc-badge">▲ Đề chuẩn &amp; Tự chọn</span>
              <span>Chấm điểm tức thì</span>
            </div>
          </div>

          <div className="bento-kpi-card">
            <div className="bkc-top">
              <span>Điều kiện đạt</span>
              <span className="bkc-icon-circle"><CheckCircle2 size={15} /></span>
            </div>
            <div className="bkc-value">
              {mode === 'template' && selectedTemplate
                ? `${selectedTemplate.passingScore}/${selectedTemplate.questionIds.length}`
                : mode === 'custom' && selectedBank
                  ? `${selectedBank.profile.passCount}/${selectedBank.profile.questionCount}`
                  : '—'} <small>câu đúng</small>
            </div>
            <div className="bkc-foot">
              <span className="bkc-trend up">● Lưu bài tự động thời gian thực</span>
            </div>
          </div>

          <div className="bento-kpi-card">
            <div className="bkc-top">
              <span>Quy tắc chấm điểm</span>
              <span className="bkc-icon-circle"><AlertTriangle size={15} /></span>
            </div>
            <div className="bkc-value">Theo đề <small>đã chọn</small></div>
            <div className="bkc-foot">
              <span>Điều kiện chi tiết hiển thị khi bắt đầu bài thi</span>
            </div>
          </div>

          <div className="bento-kpi-card is-dark-telemetry">
            <div className="bkc-top">
              <span>Đồng hồ Sát hạch</span>
              <span className="bkc-live-dot" />
            </div>
            <div className="bkc-value" style={{ fontVariantNumeric: 'tabular-nums', letterSpacing: '0.5px' }}>
              {mode === 'template' ? (selectedTemplate ? `${selectedTemplate.durationMinutes}:00` : '—') : `${customMinutes}:00`} <small>phút</small>
            </div>
            <div className="bkc-foot">
              <span style={{ color: '#9ed8c0', fontSize: '11.5px', fontWeight: 600 }}>● Sẵn sàng bấm giờ máy chủ</span>
            </div>
          </div>
        </div>

        {showScene && <div className="learning-scene-panel"><TrafficScene variant="compact" /></div>}

        {setupError && (
          <div role="alert" className="error">
            {setupError}
            <button type="button" className="link-button" onClick={() => void loadSetupData()}>
              Thử tải lại
            </button>
          </div>
        )}

        {loadingSetup ? (
          <div className="state-box" role="status">
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: '8px' }}>
              <LoaderCircle size={16} className="spin" /> Đang tải danh sách đề chuẩn và ngân hàng câu hỏi…
            </span>
          </div>
        ) : (
          <>
            {/* Two Distinct Choice Modes */}
            <div className="exam-mode-grid" role="tablist" aria-label="Chọn hình thức làm bài">
              <button
                type="button"
                role="tab"
                aria-selected={mode === 'template'}
                className={`exam-mode-card ${mode === 'template' ? 'active' : ''}`}
                onClick={() => setMode('template')}
              >
                <div className="exam-mode-card-header">
                  <span className="exam-mode-badge">Lựa chọn 1 · Đề chuẩn</span>
                  <FileCheck2 size={20} color="var(--primary)" />
                </div>
                <h2>Thi thử theo đề chuẩn</h2>
                <p>
                  Làm bài theo đề mẫu đã xuất bản với đúng số câu, thời gian quy định và ngưỡng điểm đạt chuẩn sát hạch.
                </p>
              </button>

              <button
                type="button"
                role="tab"
                aria-selected={mode === 'custom'}
                className={`exam-mode-card ${mode === 'custom' ? 'active' : ''}`}
                onClick={() => setMode('custom')}
              >
                <div className="exam-mode-card-header">
                  <span className="exam-mode-badge">Lựa chọn 2 · Tự chọn số câu</span>
                  <Sliders size={20} color="var(--primary)" />
                </div>
                <h2>Luyện tập theo số câu</h2>
                <p>
                  Rút ngẫu nhiên số câu hỏi và thời gian mong muốn từ ngân hàng câu hỏi đã xuất bản để ôn luyện nhanh.
                </p>
              </button>
            </div>

            <div className="exam-setup-layout">
              {/* Left Column: Option Configuration */}
              <section className="exam-setup-panel" aria-label="Thiết lập đề">
                {mode === 'template' ? (
                  <>
                    <h2 style={{ fontSize: '17px', marginBottom: '6px' }}>Chọn đề chuẩn đã xuất bản</h2>
                    <p className="muted" style={{ marginBottom: '12px' }}>
                      Mỗi đề chuẩn cố định danh sách câu hỏi, thời gian và điều kiện đạt theo phiên bản bộ câu hỏi.
                    </p>

                    <label>
                      Đề mẫu
                      <select
                        value={selectedTemplateKey}
                        onChange={e => setSelectedTemplateKey(e.target.value)}
                      >
                        <option value="">Chọn đề mẫu</option>
                        {templates.map(t => (
                          <option key={`${t.examCode}/${t.version}`} value={`${t.examCode}/${t.version}`}>
                            {t.title} · Phiên bản {t.version} · {t.questionIds.length} câu · {t.durationMinutes} phút
                          </option>
                        ))}
                      </select>
                    </label>

                    {templates.length === 0 ? (
                      <div className="state-box">
                        <strong>Chưa có đề chuẩn nào được xuất bản.</strong>
                        <span>Bạn có thể chuyển sang tab &ldquo;Luyện tập theo số câu&rdquo; để tạo đề từ ngân hàng câu hỏi.</span>
                      </div>
                    ) : (
                      <div className="exam-template-list" role="list">
                        {templates.map(t => {
                          const key = `${t.examCode}/${t.version}`;
                          const active = selectedTemplateKey === key;
                          return (
                            <button
                              key={key}
                              type="button"
                              role="listitem"
                              className={`exam-template-item ${active ? 'selected' : ''}`}
                              onClick={() => setSelectedTemplateKey(key)}
                            >
                              <div>
                                <strong>{t.title}</strong>
                                <small>
                                  Mã đề: {t.examCode} · Phiên bản {t.version} · Cần đạt {t.passingScore}/{t.questionIds.length} câu
                                </small>
                              </div>
                              <span className="ql-badge license">{t.durationMinutes} phút</span>
                            </button>
                          );
                        })}
                      </div>
                    )}
                  </>
                ) : (
                  <>
                    <h2 style={{ fontSize: '17px', marginBottom: '6px' }}>Thiết lập đề luyện tập theo số câu</h2>
                    <p className="muted" style={{ marginBottom: '14px' }}>
                      Chọn ngân hàng câu hỏi, số lượng câu và thời gian làm bài phù hợp với quỹ thời gian của bạn.
                    </p>

                    <label>
                      Ngân hàng câu hỏi
                      <select
                        value={selectedBankKey}
                        onChange={e => handleBankSelectChange(e.target.value)}
                      >
                        <option value="">Chọn ngân hàng</option>
                        {banks.map(b => (
                          <option key={`${b.id}/${b.version}`} value={`${b.id}/${b.version}`}>
                            {b.title} · Phiên bản {b.version} ({b.questionCount} câu)
                          </option>
                        ))}
                      </select>
                    </label>

                    {isSelectedBankOfficial && (
                      <div className="alert-warning" style={{ marginTop: '12px' }}>
                        <strong>Lưu ý quy tắc sát hạch chính thức:</strong> Ngân hàng <em>{selectedBank?.title}</em> áp dụng
                        cấu trúc sát hạch cố định ({selectedBank?.profile.questionCount} câu /{' '}
                        {Math.ceil((selectedBank?.profile.durationSeconds ?? 1200) / 60)} phút, không cho phép tạo đề rút gọn
                        1 câu). Bạn nên giữ nguyên thông số chuẩn bên dưới hoặc chuyển sang <strong>Thi thử theo đề chuẩn</strong>.
                      </div>
                    )}

                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginTop: '12px' }}>
                      <label>
                        Số câu hỏi (1–{Math.min(100, selectedBank?.questionCount ?? 100)})
                        <input
                          type="number"
                          min="1"
                          max={Math.min(100, selectedBank?.questionCount ?? 100)}
                          value={customCount}
                          onChange={e => setCustomCount(Number(e.target.value))}
                        />
                      </label>
                      <label>
                        Thời gian (phút, 1–180)
                        <input
                          type="number"
                          min="1"
                          max="180"
                          value={customMinutes}
                          onChange={e => setCustomMinutes(Number(e.target.value))}
                        />
                      </label>
                    </div>
                  </>
                )}
              </section>

              {/* Right Column: Configuration Confirmation Summary before Start */}
              <aside className="exam-confirm-card" aria-label="Xác nhận cấu hình trước khi bắt đầu">
                <span className="eyebrow">XÁC NHẬN CẤU HÌNH BÀI LÀM</span>
                <h2 style={{ fontSize: '18px', margin: '6px 0 6px' }}>
                  {mode === 'template'
                    ? selectedTemplate?.title || 'Chưa chọn đề chuẩn'
                    : selectedBank?.title || 'Chưa chọn ngân hàng câu hỏi'}
                </h2>
                <p className="muted" style={{ margin: 0 }}>
                  Kiểm tra kỹ thông số bài thi trước khi đồng hồ bắt đầu tính giờ trên máy chủ.
                </p>

                <dl className="exam-specs-dl">
                  <dt>Hình thức</dt>
                  <dd>{mode === 'template' ? 'Thi thử theo đề chuẩn' : 'Luyện tập theo số câu'}</dd>

                  <dt>Số lượng câu</dt>
                  <dd>
                    {mode === 'template'
                      ? `${selectedTemplate?.questionIds.length ?? 0} câu hỏi`
                      : `${customCount} câu hỏi`}
                  </dd>

                  <dt>Thời gian làm</dt>
                  <dd>
                    {mode === 'template'
                      ? `${selectedTemplate?.durationMinutes ?? 0} phút`
                      : `${customMinutes} phút`}
                  </dd>

                  <dt>Điều kiện đạt</dt>
                  <dd>
                    {mode === 'template'
                      ? selectedTemplate
                        ? `Đúng từ ${selectedTemplate.passingScore}/${selectedTemplate.questionIds.length} câu`
                        : '—'
                      : selectedBank
                        ? `Theo tỷ lệ chuẩn (${selectedBank.profile.passCount}/${selectedBank.profile.questionCount})`
                        : '—'}
                  </dd>

                  <dt>Nguồn câu hỏi</dt>
                  <dd>
                    {mode === 'template'
                      ? selectedTemplate
                        ? `Mã đề ${selectedTemplate.examCode} · v${selectedTemplate.version}`
                        : '—'
                      : selectedBank
                        ? `${selectedBank.sourceDescription || selectedBank.title} (v${selectedBank.version})`
                        : '—'}
                  </dd>
                </dl>

                <label className="exam-confirm-check">
                  <input
                    type="checkbox"
                    checked={confirmedConfig}
                    onChange={e => setConfirmedConfig(e.target.checked)}
                  />
                  <span>
                    Tôi xác nhận cấu hình trên và sẵn sàng bắt đầu tính giờ làm bài.
                  </span>
                </label>

                <button
                  type="button"
                  className="btn-primary"
                  style={{ width: '100%', padding: '14px 20px', fontSize: '15px' }}
                  disabled={
                    starting ||
                    !confirmedConfig ||
                    (mode === 'template' ? !selectedTemplate : !validCustomConfig)
                  }
                  onClick={() => void startSelectedExam()}
                >
                  {starting ? (
                    <>
                      <LoaderCircle size={18} className="spin" /> Đang khởi tạo đề…
                    </>
                  ) : (
                    <>
                      <Play size={18} /> {mode === 'template' ? 'Bắt đầu đề chuẩn' : 'Bắt đầu luyện tập'}
                    </>
                  )}
                </button>
              </aside>
            </div>

            {/* Resume Exam & Recent Notifications */}
            <div className="exam-aux-grid">
              <section className="exam-aux-card">
                <h3>
                  <History size={16} color="var(--primary)" /> Tiếp tục bài đang làm bằng mã đề
                </h3>
                <p className="muted" style={{ marginBottom: '10px' }}>
                  Nhập mã bài làm để tiếp tục từ câu trả lời đã lưu. Thời gian vẫn tính từ lúc bắt đầu bài:
                </p>
                <form onSubmit={resumeExamById} style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                  <input
                    style={{ flex: 1, minWidth: '200px' }}
                    placeholder="Dán mã bài làm của bạn…"
                    value={resumeId}
                    onChange={e => setResumeId(e.target.value)}
                    aria-label="Mã đề cần tiếp tục"
                  />
                  <button type="submit" className="btn-secondary" disabled={starting || !resumeId.trim()}>
                    Tiếp tục
                  </button>
                </form>
              </section>

              <section className="exam-aux-card">
                <h3>
                  <Bell size={16} color="var(--primary)" /> Thông báo chấm thi gần đây
                </h3>
                {notifications.length === 0 ? (
                  <p className="muted" style={{ margin: 0 }}>
                    Chưa có thông báo mới. Kết quả sẽ xuất hiện sau khi bài làm được chấm.
                  </p>
                ) : (
                  <ul style={{ margin: 0, paddingLeft: '18px', fontSize: '13px', display: 'grid', gap: '6px' }}>
                    {notifications.slice(0, 5).map(item => (
                      <li key={item.eventId || item.examId}>
                        Đề <code>{item.examId.slice(0, 8)}…</code>: đúng{' '}
                        <strong>
                          {item.correct}/{item.total}
                        </strong>{' '}
                        câu.
                      </li>
                    ))}
                  </ul>
                )}
              </section>
            </div>
          </>
        )}
      </div>
    </main>
  );
}
