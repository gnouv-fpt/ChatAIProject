// Result/review views must receive this URL only after the server authorizes answer visibility.
// A client-side canReview flag alone is not authorization; never send URLs in active exam DTOs.
import { isAllowedAnimationUrl } from './animation-url';

export function ExplanationAnimationLink({ url, allowedHosts, canReview, localAssetOrigin }: {
  url?: string; allowedHosts: string[]; canReview: boolean; localAssetOrigin?: string | null;
}) {
  if (!canReview || !url || !isAllowedAnimationUrl(url, allowedHosts, localAssetOrigin)) return null;
  return <a href={url} target="_blank" rel="noopener noreferrer">Xem mô phỏng 3D <span aria-hidden="true">↗</span></a>;
}
