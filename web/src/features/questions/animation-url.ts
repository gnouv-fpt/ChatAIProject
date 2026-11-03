export function isAllowedAnimationUrl(url: string | undefined, allowedHosts: string[], localAssetOrigin?: string | null): boolean {
  if (!url || url.length > 2048) return false;
  let parsed: URL, decoded: string;
  try { parsed = new URL(url); decoded = decodeURIComponent(url); } catch { return false; }
  let local = false;
  if (localAssetOrigin) {
    try {
      const root = new URL(localAssetOrigin);
      local = root.protocol === 'http:' && ['localhost', '127.0.0.1', '[::1]'].includes(root.hostname) &&
        root.pathname === '/' && !root.search && !root.hash && !root.username && !root.password && parsed.origin === root.origin;
    } catch { /* An invalid local configuration never enables a link. */ }
  }
  const hosted = parsed.protocol === 'https:' && !parsed.port && allowedHosts.some(host => host.toLowerCase() === parsed.hostname.toLowerCase());
  return (hosted || local) && !parsed.username && !parsed.password && !parsed.search && !parsed.hash && !/[\s\\]/.test(url) &&
    !/[\x00-\x1f\x7f\\%]/.test(decoded) && !decoded.split('/').some(part => part === '.' || part === '..') &&
    (parsed.pathname.toLowerCase().endsWith('.html') || parsed.pathname.endsWith('/'));
}
