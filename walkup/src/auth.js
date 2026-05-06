// PKCE OAuth 2.0 flow against Spotify accounts.
// Stores tokens in localStorage. Refreshes silently before expiry.
import { CLIENT_ID, REDIRECT_URI, SCOPES, AUTH_URL, TOKEN_URL } from "./config.js";

const KEY_VERIFIER = "walkup.pkce.verifier";
const KEY_TOKEN = "walkup.token";

function randomString(len = 64) {
  const bytes = new Uint8Array(len);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"[b % 66]).join("");
}

function base64url(buf) {
  return btoa(String.fromCharCode(...new Uint8Array(buf)))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");
}

async function challengeFrom(verifier) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier));
  return base64url(digest);
}

export async function beginLogin() {
  if (CLIENT_ID === "REPLACE_WITH_YOUR_SPOTIFY_CLIENT_ID") {
    throw new Error("Set CLIENT_ID in src/config.js first.");
  }
  const verifier = randomString(96);
  const challenge = await challengeFrom(verifier);
  localStorage.setItem(KEY_VERIFIER, verifier);

  const params = new URLSearchParams({
    response_type: "code",
    client_id: CLIENT_ID,
    scope: SCOPES.join(" "),
    redirect_uri: REDIRECT_URI,
    code_challenge_method: "S256",
    code_challenge: challenge,
  });
  window.location.assign(`${AUTH_URL}?${params}`);
}

// Returns true if a code was present and successfully exchanged.
export async function handleCallback() {
  const url = new URL(window.location.href);
  const code = url.searchParams.get("code");
  const error = url.searchParams.get("error");
  if (!code && !error) return false;

  // Clean URL regardless.
  url.search = "";
  history.replaceState({}, "", url.toString());

  if (error) throw new Error(`Spotify auth error: ${error}`);

  const verifier = localStorage.getItem(KEY_VERIFIER);
  if (!verifier) throw new Error("Missing PKCE verifier; restart login.");

  const body = new URLSearchParams({
    grant_type: "authorization_code",
    code,
    redirect_uri: REDIRECT_URI,
    client_id: CLIENT_ID,
    code_verifier: verifier,
  });
  const res = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!res.ok) throw new Error(`Token exchange failed: ${res.status} ${await res.text()}`);
  const tok = await res.json();
  storeToken(tok);
  localStorage.removeItem(KEY_VERIFIER);
  return true;
}

function storeToken(tok) {
  const expires_at = Date.now() + (tok.expires_in - 60) * 1000;
  const merged = { ...readToken(), ...tok, expires_at };
  localStorage.setItem(KEY_TOKEN, JSON.stringify(merged));
}

function readToken() {
  try { return JSON.parse(localStorage.getItem(KEY_TOKEN) || "null") || {}; }
  catch { return {}; }
}

export function isAuthed() {
  const t = readToken();
  return Boolean(t.access_token && t.refresh_token);
}

export async function getAccessToken() {
  const t = readToken();
  if (!t.access_token) throw new Error("Not authenticated.");
  if (Date.now() < (t.expires_at || 0)) return t.access_token;
  return await refresh();
}

async function refresh() {
  const t = readToken();
  if (!t.refresh_token) throw new Error("No refresh token; re-login required.");
  const body = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: t.refresh_token,
    client_id: CLIENT_ID,
  });
  const res = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!res.ok) {
    logout();
    throw new Error(`Token refresh failed: ${res.status}`);
  }
  const tok = await res.json();
  // Spotify may or may not return a new refresh_token; preserve old if not.
  if (!tok.refresh_token) tok.refresh_token = t.refresh_token;
  storeToken(tok);
  return tok.access_token;
}

export function logout() {
  localStorage.removeItem(KEY_TOKEN);
  localStorage.removeItem(KEY_VERIFIER);
}
