export function isAllowedAnimationUrl(url: string | undefined, allowedHosts: string[]): boolean {
  if (!url || url.length > 2048) return false;
  let parsed: URL, decoded: string;
  try { parsed = new URL(url); decoded = decodeURIComponent(url); } catch { return false; }
  return parsed.protocol === 'https:' && !parsed.port && !parsed.username && !parsed.password && !parsed.search && !parsed.hash &&
    allowedHosts.some(host => host.toLowerCase() === parsed.hostname.toLowerCase()) && !/[\s\\]/.test(url) &&
    !/[\x00-\x1f\x7f\\%]/.test(decoded) && !decoded.split('/').some(part => part === '.' || part === '..') &&
    (parsed.pathname.toLowerCase().endsWith('.html') || parsed.pathname.endsWith('/'));
}
