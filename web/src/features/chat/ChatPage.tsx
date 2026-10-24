import { useEffect, useRef, useState } from 'react';
import { ArrowUp, ArrowUpRight, Check, ImagePlus, LoaderCircle, Plus, ShieldCheck, Trash2, X } from 'lucide-react';
import { api } from '../../api';
import type { Attachment, Message, SendRequest, Session } from '../../api';

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
    const result = await api<{ items: Session[]; totalPages: number }>(`/chats?pageSize=20&pageIndex=${pageIndex}&search=${encodeURIComponent(query)}`);
    setSessions(previous => pageIndex === 1 ? result.items : [...previous, ...result.items]);
    setMore(result.totalPages > pageIndex); setPage(pageIndex);
  }
  useEffect(() => {
    const timer = setTimeout(() => { setLoading(true); loadSessions(1, search).catch(e => setError(e.message)).finally(() => setLoading(false)); }, 200);
    return () => clearTimeout(timer);
  }, [search]);
  useEffect(() => { end.current?.scrollIntoView({ behavior: 'smooth' }); }, [messages, busy]);
  async function select(id: string) {
    if (busy) return;
    setBusy(true); setError('');
    try { const result = await api<{ messages: Message[] }>(`/chats/${id}`); setActive(id); setShowHistory(false); setMessages(result.messages); setImages([]); setFailed(null); setPrompt(''); }
    catch (e) { setError((e as Error).message); } finally { setBusy(false); }
  }
  async function ensureSession() {
    if (active) return active;
    const created = await api<Session>('/chats', { method: 'POST', body: JSON.stringify({ title: prompt.trim().slice(0, 80) || undefined }) });
    setActive(created.id); setSessions(previous => [created, ...previous]); return created.id;
  }
  async function send(retry = false) {
    if (busy || (!retry && !prompt.trim())) return;
    setBusy(true); setError('');
    try {
      const recover = failed && (retry || (failed.sessionId === active && failed.request.prompt === prompt.trim() &&
        JSON.stringify(failed.request.attachmentIds) === JSON.stringify(images.map(i => i.id)) && failed.request.usePreviousAttachments === reuseImages));
      const sessionId = recover && failed ? failed.sessionId : await ensureSession();
      const request = recover && failed ? failed.request : { requestId: crypto.randomUUID(), prompt: prompt.trim(), attachmentIds: images.map(i => i.id), usePreviousAttachments: reuseImages };
      setFailed({ sessionId, request });
      await api<Message>(`/chats/${sessionId}/messages`, { method: 'POST', body: JSON.stringify(request) });
      setFailed(null); setPrompt(''); setImages([]);
      const detail = await api<{ messages: Message[] }>(`/chats/${sessionId}`);
      setMessages(detail.messages); await loadSessions();
    } catch (e) { setError((e as Error).message); } finally { setBusy(false); }
  }
  async function upload(file?: File) {
    if (!file || busy) return;
    if (images.length >= 3 || file.size > 5 * 1024 * 1024 || !['image/png', 'image/jpeg', 'image/webp'].includes(file.type)) {
      setError('Chọn tối đa 3 ảnh JPEG, PNG hoặc WebP, mỗi ảnh tối đa 5 MB.'); return;
    }
    setBusy(true); setError('');
    try {
      const id = await ensureSession(); const body = new FormData(); body.append('file', file);
      const attachment = await api<Attachment>(`/chats/${id}/attachments`, { method: 'POST', body });
      setImages(previous => [...previous, attachment]); setFailed(null);
    } catch (e) { setError((e as Error).message); } finally { setBusy(false); }
  }
  async function removeImage(image: Attachment) {
    setBusy(true);
    try { await api(`/chats/${active}/attachments/${image.id}`, { method: 'DELETE' }); setImages(previous => previous.filter(i => i.id !== image.id)); setFailed(null); }
    catch (e) { setError((e as Error).message); } finally { setBusy(false); }
  }
  async function removeSession(id: string) {
    if (!confirm('Xóa cuộc trò chuyện này?')) return;
    setBusy(true);
    try { await api(`/chats/${id}`, { method: 'DELETE' }); if (active === id) { setActive(null); setMessages([]); setFailed(null); setImages([]); } await loadSessions(); }
    catch (e) { setError((e as Error).message); } finally { setBusy(false); }
  }
  return <main className="chat-layout"><aside className={`history ${showHistory ? "mobile-open" : ""}`}><div className="history-heading"><h2>Cuộc trò chuyện</h2><button className="icon-button" aria-label="Cuộc trò chuyện mới" disabled={busy} onClick={() => { setActive(null); setMessages([]); setPrompt(''); setImages([]); setFailed(null); setError(''); }}><Plus size={20}/></button></div><input aria-label="Tìm cuộc trò chuyện" className="search" placeholder="Tìm trong lịch sử…" value={search} onChange={e => setSearch(e.target.value)}/><span className="nav-caption">LỊCH SỬ GẦN ĐÂY</span>{loading && <p className="muted">Đang tải…</p>}{!loading && sessions.length === 0 && <p className="muted">Cuộc trò chuyện của bạn sẽ xuất hiện ở đây.</p>}<div className="session-list">{sessions.map(s => <div key={s.id} className={`session ${active === s.id ? 'selected' : ''}`}><button disabled={busy} onClick={() => select(s.id)}><span>{s.title}</span><small>{new Date(s.lastUpdatedAt).toLocaleDateString('vi-VN')}</small></button><button className="icon-button" aria-label={`Xóa ${s.title}`} disabled={busy} onClick={() => removeSession(s.id)}><Trash2 size={14}/></button></div>)}</div>{more && <button className="link-button" disabled={busy} onClick={() => loadSessions(page + 1).catch(e => setError(e.message))}>Xem thêm</button>}<div className="history-tip"><ShieldCheck size={21}/><strong>Căn cứ rõ ràng.<br/>Hành trình an tâm.</strong><p>Đọc văn bản gốc để đối chiếu với tình huống của bạn.</p></div></aside><section className="conversation"><header className="chat-header"><button className="mobile-history icon-button" aria-label="Mở lịch sử" onClick={() => setShowHistory(!showHistory)}><Plus size={20}/></button><div><span className="eyebrow">TRỢ LÝ GIAO THÔNG</span><h2>Tư vấn pháp luật</h2></div><span className="verified-badge"><ShieldCheck size={15}/> Có trích dẫn nguồn</span></header><div className="message-scroll" aria-live="polite">{messages.length === 0 ? <section className="welcome"><div className="welcome-symbol">↗</div><span className="eyebrow">MỘT CÂU HỎI, THÊM MỘT ĐIỀU RÕ</span><h1>Hôm nay bạn muốn<br/>hiểu rõ điều gì?</h1><p>Từ biển báo đến tình huống trên đường,<br/>cùng tìm câu trả lời có căn cứ.</p><div className="suggestions">{['Vượt đèn đỏ xe máy bị xử phạt thế nào?', 'Cần mang giấy tờ gì khi lái xe?', 'Giải thích biển báo trong ảnh của tôi'].map((text, i) => <button key={text} disabled={busy} onClick={() => { setPrompt(text); setFailed(null); }}><span className="suggestion-number">0{i + 1}</span><span>{text}</span><ArrowUpRight size={17}/></button>)}</div></section> : <div className="messages">{messages.map(message => <article key={message.id} className={`message ${message.senderRole === 'User' ? 'from-user' : 'from-assistant'}`}><div className="message-author">{message.senderRole === 'User' ? 'Bạn' : '↗ Lộ trình'}{message.senderRole === 'Assistant' && message.status !== 'Answered' && <span className="status-chip">{{ NoMatch: 'Chưa tìm được căn cứ', Blocked: 'Không thể hỗ trợ', NeedsClarification: 'Cần thêm thông tin' }[message.status] ?? message.status}</span>}</div>{message.attachmentIds?.length > 0 && <div className="image-row">{message.attachmentIds.map(id => <PrivateImage key={id} sessionId={active!} id={id}/>)}</div>}<div className="message-content">{message.content}</div>{message.citations?.length > 0 && <div className="citations"><span className="eyebrow"><Check size={13}/> CĂN CỨ PHÁP LÝ</span>{message.citations.map((citation, i) => <details key={citation.id}><summary><span className="citation-index">{i + 1}</span><span>{citation.documentTitle}<small>{[citation.articleNumber && `Điều ${citation.articleNumber}`, citation.clauseNumber && `Khoản ${citation.clauseNumber}`, citation.pointNumber && `Điểm ${citation.pointNumber}`].filter(Boolean).join(' · ')}</small></span></summary><blockquote>{citation.excerpt}</blockquote>{isLegalUrl(citation.sourceUrl) && <a href={citation.sourceUrl} target="_blank" rel="noopener noreferrer">Đọc văn bản gốc <ArrowUpRight size={14}/></a>}</details>)}</div>}</article>)}</div>}{busy && <div className="working"><LoaderCircle className="spin" size={18}/> Đang xử lý yêu cầu…</div>}<div ref={end}/></div><div className="composer-area">{error && <div role="alert" className="error">{error}{failed && <button className="link-button" disabled={busy} onClick={() => send(true)}>Thử lại câu hỏi này</button>}</div>}<form className="composer" onSubmit={e => { e.preventDefault(); send(); }}>{images.length > 0 && <div className="image-row">{images.map(image => <div className="attached" key={image.id}><PrivateImage sessionId={active!} id={image.id}/><button type="button" disabled={busy} aria-label="Gỡ ảnh" onClick={() => removeImage(image)}><X size={14}/></button></div>)}</div>}<textarea aria-label="Câu hỏi pháp luật" placeholder="Nhập câu hỏi hoặc đính kèm ảnh biển báo…" value={prompt} maxLength={2000} disabled={busy} onChange={e => { setPrompt(e.target.value); setFailed(null); }} onKeyDown={e => { if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) { e.preventDefault(); send(); } }}/><div className="composer-toolbar"><label className={`attach-button ${busy ? 'disabled' : ''}`}><ImagePlus size={18}/><span>Thêm ảnh</span><input type="file" aria-label="Thêm ảnh" accept="image/jpeg,image/png,image/webp" disabled={busy || images.length >= 3} onChange={e => { upload(e.target.files?.[0]); e.target.value = ''; }}/></label><label className="reuse-images"><input type="checkbox" checked={reuseImages} disabled={busy} onChange={e => { setReuseImages(e.target.checked); setFailed(null); }}/>Dùng ảnh trước</label><small>{prompt.length}/2000</small><button className="send-button" aria-label="Gửi câu hỏi" disabled={busy || !prompt.trim()}>{busy ? <LoaderCircle size={18} className="spin"/> : <ArrowUp size={20}/>}</button></div></form><p className="composer-note">Thông tin tham khảo. Hãy đối chiếu văn bản gốc và tình huống thực tế.</p></div></section></main>;
}
function isLegalUrl(url: string) { try { const source = new URL(url); return source.protocol === 'https:' && (source.hostname === 'thuvienphapluat.vn' || source.hostname.endsWith('.thuvienphapluat.vn')); } catch { return false; } }
function PrivateImage({ sessionId, id }: { sessionId: string; id: string }) {
  const [url, setUrl] = useState('');
  const [error, setError] = useState(false);
  useEffect(() => {
    let disposed = false; let objectUrl = '';
    api<Blob>(`/chats/${sessionId}/attachments/${id}`).then(blob => { if (!disposed) { objectUrl = URL.createObjectURL(blob); setUrl(objectUrl); } }).catch(() => { if (!disposed) setError(true); });
    return () => { disposed = true; if (objectUrl) URL.revokeObjectURL(objectUrl); };
  }, [sessionId, id]);
  return error ? <span className="muted">Ảnh đã hết hạn hoặc không khả dụng</span> : url ? <img className="private-image" src={url} alt="Ảnh đính kèm cuộc trò chuyện"/> : <span className="muted">Đang tải ảnh…</span>;
}
