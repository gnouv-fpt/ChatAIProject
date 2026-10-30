// Result/review views must receive this URL only after the server authorizes answer visibility.
// A client-side canReview flag alone is not authorization; never send URLs in active exam DTOs.
import { isAllowedAnimationUrl } from './animation-url';

export function ExplanationAnimationLink({ url, allowedHosts, canReview }: {
  url?: string; allowedHosts: string[]; canReview: boolean;
}) {
  if (!canReview || !url || !isAllowedAnimationUrl(url, allowedHosts)) return null;
  return <a href={url} target="_blank" rel="noopener noreferrer">Xem minh họa lời giải <span aria-hidden="true">↗</span></a>;
}
