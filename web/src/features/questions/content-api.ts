export type ContentApi = <T>(path: string, init?: RequestInit) => Promise<T>;
export type Bank = { id: string; version: string; title: string; sourceUrl: string; sourceDescription: string;
  questionCount: number; hash: string; isPublished: boolean;
  profile: { id: string; version: string; questionCount: number; durationSeconds: number; passCount: number } };
export type Question = { id: string; number: number; topic: string; text: string;
  options: { id: string; text: string }[]; assets: { id: string; url: string; altText: string }[]; sourceUrl: string };
export type Page<T> = { items: T[]; totalCount: number; pageIndex: number; pageSize: number };
export type Preview = { summary: Bank; bank: unknown; errors: string[] };

// The shell supplies auth; tokens are kept in memory and never added to URLs/storage.
export function createContentApi(token: string): ContentApi {
  return async <T,>(path: string, init?: RequestInit): Promise<T> => {
    const headers = new Headers(init?.headers);
    headers.set('Authorization', `Bearer ${token}`);
    if (init?.body) headers.set('Content-Type', 'application/json');
    const response = await fetch(path, { ...init, headers });
    if (!response.ok) {
      const problem = await response.json().catch(() => null);
      throw new Error(problem?.detail ?? (response.status === 401 ? 'Phiên đăng nhập không hợp lệ.' : `Yêu cầu thất bại (${response.status}).`));
    }
    return response.json() as Promise<T>;
  };
}
export const bankPath = (bank: Bank) => `/api/question-banks/${bank.id}/versions/${encodeURIComponent(bank.version)}`;
