const BACKEND_URL = import.meta.env.VITE_BACKEND_URL || import.meta.env.VITE_SOCKET_URL || 'https://adnanmohammed-cima-back.hf.space';

const TIMEOUT = 90000;
const MAX_RETRIES = 1;

async function fetchStream(tmdbId, type = 'movie', season = null, episode = null, provider = null) {
  const params = new URLSearchParams({ tmdb_id: tmdbId, type });
  if (season) params.set('season', season);
  if (episode) params.set('episode', episode);
  if (provider) params.set('provider', provider);

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), TIMEOUT);
    try {
      const res = await fetch(`${BACKEND_URL}/api/stream?${params}`, { signal: controller.signal });
      if (!res.ok) {
        const err = await res.json().catch(() => ({ error: 'Stream fetch failed' }));
        throw new Error(err.error || 'Stream fetch failed');
      }
      return await res.json();
    } catch (err) {
      clearTimeout(timeoutId);
      if (err.name === 'AbortError') {
        if (attempt < MAX_RETRIES) continue;
        throw new Error('Stream request timed out');
      }
      throw err;
    }
  }
}

export { fetchStream };
