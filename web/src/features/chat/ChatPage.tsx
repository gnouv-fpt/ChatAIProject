import { useEffect, useRef, useState } from 'react';
import {
  AlertTriangle,
  ArrowUp,
  ArrowUpRight,
  Check,
  HelpCircle,
  ImagePlus,
  LoaderCircle,
  MessageSquare,
  Plus,
  ShieldAlert,
  ShieldCheck,
  Trash2,
  X,
} from 'lucide-react';
import { api } from '../../api';
import type { Attachment, Message, SendRequest, Session } from '../../api';

const statusLabels: Record<string, string> = {
  PracticeAnswered: 'Đáp án bộ CSGT',
  NoMatch: 'Chưa tìm được căn cứ',
  Blocked: 'Không thể hỗ trợ',
  NeedsClarification: 'Cần thêm thông tin',
};

const statusGuidance: Record<string, { title: string; nextStep: string }> = {
  NoMatch: {
    title: 'Chưa tìm thấy điều khoản khớp trực tiếp trong kho văn bản đã xác minh',
    nextStep:
      'Gợi ý bước tiếp theo: Hãy nêu rõ loại phương tiện (ô tô, xe máy, xe tải), hành vi cụ thể hoặc tra cứu trực tiếp tại mục Văn bản pháp luật.',
  },
  NeedsClarification: {
    title: 'Tình huống cần bổ sung thêm thông tin để đối chiếu đúng quy định',
    nextStep:
      'Gợi ý bước tiếp theo: Hãy cho biết thêm loại xe, tốc độ, mức nồng độ cồn, loại biển báo hoặc khu vực (trong hay ngoài khu đông dân cư).',
  },
  Blocked: {
    title: 'Yêu cầu nằm ngoài phạm vi tư vấn pháp luật giao thông đường bộ',
    nextStep:
      'Gợi ý bước tiếp theo: Vui lòng đặt câu hỏi xoay quanh quy tắc giao thông, biển báo, giấy tờ xe hoặc mức xử phạt vi phạm hành chính.',
  },
};

function noMatchGuidance(question?: Message): { title: string; nextStep: string } {
  const text = question?.content ?? '';
  if (/xử phạt|mức phạt|bị phạt|phạt bao nhiêu/i.test(text)) {
    return {
      title: 'Chưa đủ căn cứ để xác định mức xử phạt cho tình huống này',
      nextStep: 'Hãy nêu rõ loại xe, hành vi và ngày vi phạm; với quy định về thiết bị ghi hình, cần thêm loại hình vận tải. Bạn cũng có thể tra cứu văn bản gốc tại mục Văn bản pháp luật.',
    };
  }
  if (question?.attachmentIds?.length) {
    return {
      title: 'Chưa đủ căn cứ để kết luận từ ảnh này',
      nextStep: 'Hãy kiểm tra ảnh có đủ mũi tên, biển báo và các phương án. Với sa hình, hệ thống chỉ chọn thứ tự xe khi đọc rõ tình huống và đối chiếu được quy tắc.',
    };
  }
  if (/sa hình|thứ tự.*xe|xe.*đi trước|hướng mũi tên/i.test(text) && !question?.attachmentIds?.length) {
    return {
      title: 'Cần ảnh sa hình gốc để xác định vị trí và hướng đi của từng xe',
      nextStep: 'Hãy đính kèm ảnh sa hình và ghi số câu hoặc các phương án. Chỉ mô tả bằng chữ không đủ dữ kiện để xác định thứ tự xe.',
    };
  }
  return statusGuidance.NoMatch;
}

function answerContent(content: string, hasStructuredCitations: boolean, linkifyPractice: boolean) {
  const withoutRepeatedLegalBasis = hasStructuredCitations
    ? content.replace(/(?:^|\n)\s*(?:\*\*)?Căn cứ pháp lý:?(?:\*\*)?[\s\S]*$/i, '').trimEnd()
    : content;
  return withoutRepeatedLegalBasis.split(/(\*\*[^*]+\*\*|https:\/\/[^\s]+)/g).map((part, index) => {
    if (part.startsWith('**') && part.endsWith('**')) {
      return <strong key={index}>{part.slice(2, -2)}</strong>;
    }
    if (!linkifyPractice || !part.startsWith('https://')) return part;
    try {
      const url = new URL(part);
      if (url.hostname === 'khodulieu.sohoa.tuyenquang.gov.vn' ||
          url.hostname === 'content-animations.vercel.app') {
        const label = url.hostname === 'content-animations.vercel.app' ? 'Xem ảnh gốc' : 'Mở PDF câu hỏi CSGT';
        return <a key={index} href={url.href} target="_blank" rel="noopener noreferrer">{label}</a>;
      }
    } catch { /* Keep malformed source text visible. */ }
    return part;
  });
}

export function ChatPage() {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [active, setActive] = useState<string | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [prompt, setPrompt] = useState('');
  const [images, setImages] = useState<Attachment[]>([]);
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [failed, setFailed] = useState<{ sessionId: string; request: SendRequest } | null>(null);
  const [showHistory, setShowHistory] = useState(false);
  const [reuseImages, setReuseImages] = useState(true);
  const [search, setSearch] = useState('');
  const [more, setMore] = useState(false);
  const [page, setPage] = useState(1);
  const end = useRef<HTMLDivElement>(null);

  async function loadSessions(pageIndex = 1, query = search) {
    const result = await api<{ items: Session[]; totalPages: number }>(
      `/chats?pageSize=20&pageIndex=${pageIndex}&search=${encodeURIComponent(query)}`
    );
    setSessions(previous => (pageIndex === 1 ? result.items : [...previous, ...result.items]));
    setMore(result.totalPages > pageIndex);
    setPage(pageIndex);
  }

  useEffect(() => {
    const timer = setTimeout(() => {
      setLoading(true);
      loadSessions(1, search)
        .catch(e => setError(e.message))
        .finally(() => setLoading(false));
    }, 200);
    return () => clearTimeout(timer);
  }, [search]);

  useEffect(() => {
    // Only follow the conversation once it exists; on an empty chat keep the welcome heading in view.
    if (messages.length === 0 && !busy) return;
    end.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, busy]);

  async function select(id: string) {
    if (busy) return;
    setBusy(true);
    setError('');
    try {
      const result = await api<{ messages: Message[] }>(`/chats/${id}`);
      setActive(id);
      setShowHistory(false);
      setMessages(result.messages);
      setImages([]);
      setFailed(null);
      setPrompt('');
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function ensureSession() {
    if (active) return active;
    const created = await api<Session>('/chats', {
      method: 'POST',
      body: JSON.stringify({ title: prompt.trim().slice(0, 80) || undefined }),
    });
    setActive(created.id);
    setSessions(previous => [created, ...previous]);
    return created.id;
  }

  async function send(retry = false) {
    if (busy || (!retry && !prompt.trim())) return;
    setBusy(true);
    setError('');
    try {
      const recover =
        failed &&
        (retry ||
          (failed.sessionId === active &&
            failed.request.prompt === prompt.trim() &&
            JSON.stringify(failed.request.attachmentIds) === JSON.stringify(images.map(i => i.id)) &&
            failed.request.usePreviousAttachments === reuseImages));
      const sessionId = recover && failed ? failed.sessionId : await ensureSession();
      const request =
        recover && failed
          ? failed.request
          : {
              requestId: crypto.randomUUID(),
              prompt: prompt.trim(),
              attachmentIds: images.map(i => i.id),
              usePreviousAttachments: reuseImages,
            };
      setFailed({ sessionId, request });
      await api<Message>(`/chats/${sessionId}/messages`, {
        method: 'POST',
        body: JSON.stringify(request),
      });
      setFailed(null);
      setPrompt('');
      setImages([]);
      const detail = await api<{ messages: Message[] }>(`/chats/${sessionId}`);
      setMessages(detail.messages);
      await loadSessions();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function upload(file?: File) {
    if (!file || busy) return;
    if (
      images.length >= 3 ||
      file.size > 5 * 1024 * 1024 ||
      !['image/png', 'image/jpeg', 'image/webp'].includes(file.type)
    ) {
      setError('Chọn tối đa 3 ảnh JPEG, PNG hoặc WebP, mỗi ảnh tối đa 5 MB.');
      return;
    }
    setBusy(true);
    setError('');
    try {
      const id = await ensureSession();
      const body = new FormData();
      body.append('file', file);
      const attachment = await api<Attachment>(`/chats/${id}/attachments`, { method: 'POST', body });
      setImages(previous => [...previous, attachment]);
      setFailed(null);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function removeImage(image: Attachment) {
    setBusy(true);
    try {
      await api(`/chats/${active}/attachments/${image.id}`, { method: 'DELETE' });
      setImages(previous => previous.filter(i => i.id !== image.id));
      setFailed(null);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function removeSession(id: string) {
    if (!confirm('Xóa cuộc trò chuyện này?')) return;
    setBusy(true);
    try {
      await api(`/chats/${id}`, { method: 'DELETE' });
      if (active === id) {
        setActive(null);
        setMessages([]);
        setFailed(null);
        setImages([]);
      }
      await loadSessions();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="chat-layout">
      <aside className={`history ${showHistory ? 'mobile-open' : ''}`}>
        <div className="history-heading">
          <h2>Cuộc trò chuyện</h2>
          <button
            className="icon-button"
            aria-label="Cuộc trò chuyện mới"
            disabled={busy}
            onClick={() => {
              setActive(null);
              setMessages([]);
              setPrompt('');
              setImages([]);
              setFailed(null);
              setError('');
            }}
          >
            <Plus size={20} />
          </button>
        </div>

        <input
          aria-label="Tìm cuộc trò chuyện"
          className="search"
          placeholder="Tìm trong lịch sử…"
          value={search}
          onChange={e => setSearch(e.target.value)}
        />

        <span className="nav-caption">LỊCH SỬ GẦN ĐÂY</span>
        {loading && <p className="muted">Đang tải…</p>}
        {!loading && sessions.length === 0 && <p className="muted">Cuộc trò chuyện của bạn sẽ xuất hiện ở đây.</p>}

        <div className="session-list">
          {sessions.map(s => (
            <div key={s.id} className={`session ${active === s.id ? 'selected' : ''}`}>
              <button disabled={busy} onClick={() => void select(s.id)}>
                <span>{s.title}</span>
                <small>{new Date(s.lastUpdatedAt).toLocaleDateString('vi-VN')}</small>
              </button>
              <button
                className="icon-button"
                aria-label={`Xóa ${s.title}`}
                disabled={busy}
                onClick={() => void removeSession(s.id)}
              >
                <Trash2 size={14} />
              </button>
            </div>
          ))}
        </div>

        {more && (
          <button
            className="link-button"
            disabled={busy}
            onClick={() => loadSessions(page + 1).catch(e => setError(e.message))}
          >
            Xem thêm
          </button>
        )}

        <div className="history-tip">
          <ShieldCheck size={20} />
          <strong>
            Căn cứ rõ ràng.
            <br />
            Hành trình an tâm.
          </strong>
          <p>Mỗi câu trả lời đều tách bạch phần giải thích và trích dẫn Điều, Khoản, Điểm từ văn bản pháp luật.</p>
        </div>
      </aside>

      <section className="conversation">
        <header className="chat-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <button
              className="mobile-history icon-button"
              aria-label="Mở lịch sử"
              onClick={() => setShowHistory(!showHistory)}
            >
              <MessageSquare size={18} />
            </button>
            <div>
              <span className="eyebrow">TRỢ LÝ PHÁP LUẬT GIAO THÔNG</span>
              <h2>Tư vấn tình huống có trích dẫn nguồn</h2>
            </div>
          </div>
          <span className="verified-badge">
            <ShieldCheck size={15} /> <span>Đối chiếu Thư Viện Pháp Luật</span>
          </span>
        </header>

        <div className="message-scroll" aria-live="polite">
          {messages.length === 0 ? (
            <section className="welcome">
              <div className="welcome-symbol">↗</div>
              <span className="eyebrow">HỎI ĐÁP PHÁP LUẬT · SONG HÀNH CÙNG ÔN THI</span>
              <h1>
                Hôm nay bạn muốn{' '}
                <br />
                tra cứu tình huống giao thông nào?
              </h1>
              <p>
                Đặt câu hỏi bằng ngôn ngữ tự nhiên hoặc đính kèm ảnh biển báo/tình huống. Hệ thống trả lời kèm Điều,
                Khoản, Điểm và đoạn trích nguyên văn.
              </p>

              <div className="suggestions">
                {[
                  'Khi đèn tín hiệu màu đỏ, xe máy phải làm gì?',
                  'Cần mang giấy tờ gì khi lái xe?',
                  'Giải thích biển báo trong ảnh của tôi',
                ].map((text, i) => (
                  <button
                    key={text}
                    disabled={busy}
                    onClick={() => {
                      setPrompt(text);
                      setFailed(null);
                    }}
                  >
                    <span className="suggestion-number">0{i + 1}</span>
                    <span>{text}</span>
                    <ArrowUpRight size={17} />
                  </button>
                ))}
              </div>
            </section>
          ) : (
            <div className="messages">
              {messages.map((message, index) => {
                const isUser = message.senderRole === 'User';
                const guidance = !isUser && !['Answered', 'PracticeAnswered'].includes(message.status)
                  ? message.status === 'NoMatch'
                    ? noMatchGuidance(messages.slice(0, index).reverse().find(item => item.senderRole === 'User'))
                    : statusGuidance[message.status]
                  : undefined;
                return (
                  <article key={message.id} className={`message ${isUser ? 'from-user' : 'from-assistant'}`}>
                    <div className="message-author">
                      <span>{isUser ? '1. Câu hỏi của bạn' : '2. Câu trả lời tư vấn · ↗ TrafficHub'}</span>
                      <span className="message-role-tag">{isUser ? 'Tình huống' : 'Giải đáp'}</span>
                      {!isUser && message.status !== 'Answered' && (
                        <span className={`status-chip status-${message.status}`}>
                          {statusLabels[message.status] ?? message.status}
                        </span>
                      )}
                    </div>

                    {message.attachmentIds?.length > 0 && (
                      <div className="image-row">
                        {message.attachmentIds.map(id => (
                          <PrivateImage key={id} sessionId={active!} id={id} />
                        ))}
                      </div>
                    )}

                    <div className="message-content">
                      {answerContent(message.content, !isUser && (message.citations?.length ?? 0) > 0, message.status === 'PracticeAnswered')}
                    </div>

                    {/* Distinct presentation for NoMatch, NeedsClarification, Blocked */}
                    {guidance && (
                      <div className={`chat-status-guidance guidance-${message.status}`} role="note">
                        <strong style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          {message.status === 'NoMatch' ? (
                            <AlertTriangle size={15} />
                          ) : message.status === 'NeedsClarification' ? (
                            <HelpCircle size={15} />
                          ) : (
                            <ShieldAlert size={15} />
                          )}
                          {guidance.title}
                        </strong>
                        <span>{guidance.nextStep}</span>
                      </div>
                    )}

                    {/* 3. Legal Citations with Document Title, Điều/Khoản/Điểm, and visible excerpt before source link */}
                    {message.citations?.length > 0 && (
                      <div className="citations">
                        <span className="eyebrow">
                          <Check size={14} /> 3. CĂN CỨ PHÁP LÝ ({message.citations.length} trích dẫn)
                        </span>
                        {message.citations.map((citation, i) => {
                          const provisionParts = [
                            citation.articleNumber && `Điều ${citation.articleNumber}`,
                            citation.clauseNumber && `Khoản ${citation.clauseNumber}`,
                            citation.pointNumber && `Điểm ${citation.pointNumber}`,
                          ].filter(Boolean);
                          return (
                            <details key={citation.id} open className="citation-card">
                              <summary className="citation-header">
                                <span className="citation-index">{i + 1}</span>
                                <span className="citation-meta">
                                  <span className="citation-document-title" title={citation.documentTitle}>
                                    {citation.documentTitle}
                                  </span>
                                  {provisionParts.length > 0 && (
                                    <span className="citation-Provision">
                                      {provisionParts.map(part => (
                                        <small key={part} className="citation-badge">
                                          {part}
                                        </small>
                                      ))}
                                    </span>
                                  )}
                                </span>
                              </summary>
                              <blockquote>{citation.excerpt}</blockquote>
                              {isLegalUrl(citation.sourceUrl) && (
                                <a href={citation.sourceUrl} target="_blank" rel="noopener noreferrer">
                                  Đọc văn bản gốc <ArrowUpRight size={14} />
                                </a>
                              )}
                              {citation.documentTitle.includes('168/2024/NĐ-CP') && (
                                <a href="https://vanban.chinhphu.vn/?classid=0&docid=218613&pageid=27160"
                                  target="_blank" rel="noopener noreferrer">
                                  Đọc Nghị định sửa đổi 238/2026 <ArrowUpRight size={14} />
                                </a>
                              )}
                            </details>
                          );
                        })}
                      </div>
                    )}
                  </article>
                );
              })}
            </div>
          )}

          {busy && (
            <div className="working">
              <LoaderCircle className="spin" size={18} /> Đang đối chiếu văn bản pháp luật và xử lý yêu cầu…
            </div>
          )}
          <div ref={end} />
        </div>

        <div className="composer-area">
          {error && (
            <div role="alert" className="error">
              <strong>Lỗi dịch vụ / kết nối:</strong> {error}
              {failed && (
                <div>
                  <button className="link-button" disabled={busy} onClick={() => void send(true)}>
                    Thử lại câu hỏi này
                  </button>
                </div>
              )}
            </div>
          )}

          <form
            className="composer"
            onSubmit={e => {
              e.preventDefault();
              void send();
            }}
          >
            {images.length > 0 && (
              <div className="image-row">
                {images.map(image => (
                  <div className="attached" key={image.id}>
                    <PrivateImage sessionId={active!} id={image.id} />
                    <button
                      type="button"
                      disabled={busy}
                      aria-label="Gỡ ảnh"
                      onClick={() => void removeImage(image)}
                    >
                      <X size={14} />
                    </button>
                  </div>
                ))}
              </div>
            )}

            <textarea
              aria-label="Câu hỏi pháp luật"
              placeholder="Nhập tình huống giao thông hoặc đính kèm ảnh biển báo để tra cứu căn cứ…"
              value={prompt}
              maxLength={2000}
              disabled={busy}
              onChange={e => {
                setPrompt(e.target.value);
                setFailed(null);
              }}
              onKeyDown={e => {
                if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) {
                  e.preventDefault();
                  void send();
                }
              }}
            />

            <div className="composer-toolbar">
              <label className={`attach-button ${busy ? 'disabled' : ''}`}>
                <ImagePlus size={17} />
                <span>Thêm ảnh</span>
                <input
                  type="file"
                  aria-label="Thêm ảnh"
                  accept="image/jpeg,image/png,image/webp"
                  disabled={busy || images.length >= 3}
                  onChange={e => {
                    void upload(e.target.files?.[0]);
                    e.target.value = '';
                  }}
                />
              </label>

              <label className="reuse-images">
                <input
                  type="checkbox"
                  checked={reuseImages}
                  disabled={busy}
                  onChange={e => {
                    setReuseImages(e.target.checked);
                    setFailed(null);
                  }}
                />
                Dùng ảnh trước
              </label>

              <small>{prompt.length}/2000</small>

              <button
                className="send-button"
                aria-label="Gửi câu hỏi"
                disabled={busy || !prompt.trim()}
              >
                {busy ? <LoaderCircle size={18} className="spin" /> : <ArrowUp size={20} />}
              </button>
            </div>
          </form>

          <p className="composer-note">
            Thông tin phục vụ tra cứu và học tập. Hãy luôn đối chiếu văn bản gốc và chấp hành hiệu lệnh của CSGT.
          </p>
        </div>
      </section>
    </main>
  );
}

function isLegalUrl(url: string) {
  try {
    const source = new URL(url);
    return (
      source.protocol === 'https:' &&
      (source.hostname === 'thuvienphapluat.vn' || source.hostname.endsWith('.thuvienphapluat.vn'))
    );
  } catch {
    return false;
  }
}

function PrivateImage({ sessionId, id }: { sessionId: string; id: string }) {
  const [url, setUrl] = useState('');
  const [error, setError] = useState(false);
  useEffect(() => {
    let disposed = false;
    let objectUrl = '';
    api<Blob>(`/chats/${sessionId}/attachments/${id}`)
      .then(blob => {
        if (!disposed) {
          objectUrl = URL.createObjectURL(blob);
          setUrl(objectUrl);
        }
      })
      .catch(() => {
        if (!disposed) setError(true);
      });
    return () => {
      disposed = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [sessionId, id]);
  return error ? (
    <span className="muted">Ảnh đã hết hạn hoặc không khả dụng</span>
  ) : url ? (
    <img className="private-image" src={url} alt="Ảnh đính kèm cuộc trò chuyện" />
  ) : (
    <span className="muted">Đang tải ảnh…</span>
  );
}
