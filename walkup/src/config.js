// Spotify Developer app credentials.
// 1. https://developer.spotify.com/dashboard → Create app
// 2. Add this page's URL as a Redirect URI (exact match, including trailing slash).
// 3. Paste the Client ID below. No client secret is needed (PKCE flow).
export const CLIENT_ID = "REPLACE_WITH_YOUR_SPOTIFY_CLIENT_ID";

// Redirect URI is the page itself. Strips query/hash so OAuth callbacks land cleanly.
export const REDIRECT_URI = (() => {
  const u = new URL(window.location.href);
  u.search = "";
  u.hash = "";
  return u.toString();
})();

export const SCOPES = [
  "streaming",
  "user-read-email",
  "user-read-private",
  "user-read-playback-state",
  "user-modify-playback-state",
];

export const AUTH_URL = "https://accounts.spotify.com/authorize";
export const TOKEN_URL = "https://accounts.spotify.com/api/token";
export const API_BASE = "https://api.spotify.com/v1";
