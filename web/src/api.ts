export type Profile = { id: string; username: string; email: string; role: string; tokenBalance: number; tokenQuota: number };
type Auth = { accessToken: string; refreshToken: string; user: Profile };
const authStorageKey = 'csgt_auth_session';
export class ApiError extends Error {
  constructor(public status: number, message: string) { super(message); }
}
function readStoredAuth(): Auth | null {
  if (typeof window === 'undefined') return null;
  const saved = window.sessionStorage.getItem(authStorageKey);
  if (!saved) return null;
  try {
    const parsed = JSON.parse(saved) as Partial<Auth>;
    if (
      typeof parsed.accessToken === 'string' &&
      typeof parsed.refreshToken === 'string' &&
      parsed.user &&
      typeof parsed.user === 'object'
    ) {
      return parsed as Auth;
    }
  } catch {
    window.sessionStorage.removeItem(authStorageKey);
  }
  return null;
}
let auth: Auth | null = readStoredAuth();
let refreshing: Promise<void> | null = null;
export function setAuth(value: Auth | null) {
  auth = value;
  if (typeof window === 'undefined') return;
  if (value) window.sessionStorage.setItem(authStorageKey, JSON.stringify(value));
  else window.sessionStorage.removeItem(authStorageKey);
}
export function getAuth() { return auth; }
export async function api<T>(path: string, options: RequestInit = {}, retry = true): Promise<T> {
  const headers = new Headers(options.headers);
  if (auth) headers.set('Authorization', `Bearer ${auth.accessToken}`);
  if (options.body && !(options.body instanceof FormData)) headers.set('Content-Type', 'application/json');
  let response: Response;
  try { response = await fetch(`/api${path}`, { ...options, headers, cache: 'no-store' }); }
  catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') throw error;
    throw new ApiError(0, 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.');
  }
  if (response.status === 401 && auth && retry && !path.startsWith('/auth/')) {
    refreshing ??= api<Auth>('/auth/refresh-token', { method: 'POST', body: JSON.stringify({ refreshToken: auth.refreshToken }) }, false)
      .then(setAuth).catch(error => { setAuth(null); window.dispatchEvent(new Event('auth-expired')); throw error; })
      .finally(() => { refreshing = null; });
    await refreshing;
    return api<T>(path, options, false);
  }
  if (!response.ok) {
    const problem = await response.json().catch(() => ({}));
    const validation = Object.values(problem.errors ?? {}).flat().join(' ');
    throw new ApiError(response.status, problem.detail || validation || 'Yêu cầu chưa thực hiện được. Vui lòng thử lại.');
  }
  if (response.status === 204) return undefined as T;
  if (response.headers.get('Content-Type')?.startsWith('image/')) return await response.blob() as T;
  return response.json();
}
export type Session = { id: string; title: string; lastUpdatedAt: string };
export type Citation = { id: string; documentTitle: string; articleNumber: string; clauseNumber: string; pointNumber?: string; excerpt: string; sourceUrl: string };
export type Message = { id: string; senderRole: 'User' | 'Assistant'; content: string; status: string; attachmentIds: string[]; citations: Citation[] };
export type Attachment = { id: string; mimeType: string; expiresAt: string };
export type SendRequest = { requestId: string; prompt: string; attachmentIds: string[]; usePreviousAttachments?: boolean };
