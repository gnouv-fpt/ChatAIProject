import { useEffect, useRef, useState } from 'react';
import { api } from '../../api';

export type AnimationPayload = {
  assetBaseUrl: string;
  number: number;
  images: { url: string; width: number; height: number }[];
  recipe: Record<string, unknown> & {
    rendererVersion?: number;
    cleanBackground?: { url?: string };
    steps?: { text: string }[];
  };
};

type PlayerFrame = { index: number; playing: boolean };
type PlayerState = { ready: boolean; mode?: string; error?: string };
type Player = {
  mode: string;
  recipe: { steps: { text: string }[] };
  playing: boolean;
  setQuestion(question: unknown, recipe: unknown, preferredMode: string): Promise<void>;
  setMode(mode: string): Promise<void>;
  play(): void;
  pause(): void;
  step(delta: number): void;
  reset(): void;
};

type ProtectedAnimationProps =
  | { attemptId: string; questionId: string; payload?: never }
  | { attemptId?: never; questionId?: never; payload: AnimationPayload };

export function ProtectedExplanationAnimation({ attemptId, questionId, payload }: ProtectedAnimationProps) {
  const hostRef = useRef<HTMLDivElement>(null);
  const playerRef = useRef<Player | null>(null);
  const mountedRef = useRef(true);
  const [busy, setBusy] = useState(false);
  const [loaded, setLoaded] = useState(false);
  const [ready, setReady] = useState(false);
  const [mode, setMode] = useState('3d');
  const [playing, setPlaying] = useState(false);
  const [message, setMessage] = useState(payload
    ? 'Nhấn xem để tải mô phỏng đã được máy chủ cấp cho quản trị viên.'
    : 'Mô phỏng chỉ được tải sau khi máy chủ xác nhận lượt thi đã nộp.');
  const [error, setError] = useState('');

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
      playerRef.current?.pause();
    };
  }, []);

  async function load() {
    if (busy || loaded || !hostRef.current) return;
    setBusy(true);
    setError('');
    try {
      const data = payload ?? await api<AnimationPayload>(
        `/exam-attempts/${encodeURIComponent(attemptId)}/review-animations/${encodeURIComponent(questionId)}`
      );
      const version = Number(data.recipe.rendererVersion ?? 1);
      const file = version > 1 ? `review-player-v${version}.js` : 'review-player.js';
      const moduleUrl = new URL(file, data.assetBaseUrl).href;
      const module = await import(/* @vite-ignore */ moduleUrl) as Record<string, new (
        host: HTMLElement,
        onFrame: (frame: PlayerFrame) => void,
        onState: (state: PlayerState) => void
      ) => Player>;
      const exportName = version > 1 ? `ReviewPlayerV${version}` : 'ReviewPlayer';
      const PlayerType = module[exportName];
      if (!PlayerType) throw new Error('Phiên bản trình phát mô phỏng không được hỗ trợ.');

      const recipe = structuredClone(data.recipe);
      if (recipe.cleanBackground?.url) {
        recipe.cleanBackground.url = new URL(recipe.cleanBackground.url, data.assetBaseUrl).href;
      }
      const player = new PlayerType(
        hostRef.current,
        frame => {
          if (!mountedRef.current) return;
          setPlaying(frame.playing);
          const text = playerRef.current?.recipe.steps[frame.index]?.text;
          if (text) setMessage(text);
        },
        state => {
          if (!mountedRef.current) return;
          setReady(state.ready);
          if (state.mode) setMode(state.mode);
          if (state.error) setError(state.error);
        }
      );
      playerRef.current = player;
      setLoaded(true);
      await player.setQuestion({ number: data.number, images: data.images }, recipe, '3d');
    } catch (caught) {
      if (mountedRef.current) setError(caught instanceof Error ? caught.message : 'Không tải được mô phỏng.');
    } finally {
      if (mountedRef.current) setBusy(false);
    }
  }

  async function changeMode(nextMode: string) {
    if (!playerRef.current) return;
    setError('');
    await playerRef.current.setMode(nextMode);
  }

  return (
    <section className="protected-animation" aria-label="Mô phỏng lời giải được bảo vệ">
      {!loaded && (
        <button type="button" className="btn-primary" onClick={() => void load()} disabled={busy}>
          {busy ? 'Đang xác thực và tải mô phỏng…' : 'Xem mô phỏng 3D'}
        </button>
      )}
      <div ref={hostRef} className="protected-animation-scene" hidden={!loaded} />
      {loaded && (
        <div className="protected-animation-controls">
          <button type="button" aria-pressed={mode === '3d'} onClick={() => void changeMode('3d')}>Mô phỏng 3D</button>
          <button type="button" aria-pressed={mode === 'original'} onClick={() => void changeMode('original')}>Ảnh gốc</button>
          <button type="button" disabled={!ready || mode !== '3d'} onClick={() => playing ? playerRef.current?.pause() : playerRef.current?.play()}>
            {playing ? 'Tạm dừng' : 'Phát'}
          </button>
          <button type="button" disabled={!ready || mode !== '3d'} onClick={() => playerRef.current?.step(-1)}>Bước trước</button>
          <button type="button" disabled={!ready || mode !== '3d'} onClick={() => playerRef.current?.step(1)}>Bước sau</button>
          <button type="button" disabled={!ready || mode !== '3d'} onClick={() => playerRef.current?.reset()}>Về đầu</button>
        </div>
      )}
      <p role="status" className="protected-animation-message">{error || message}</p>
    </section>
  );
}
