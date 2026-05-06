// Thin wrapper over the Spotify Web API.
// Auto-refreshes the access token via auth.js and retries once on 401.
import { API_BASE } from "./config.js";
import { getAccessToken } from "./auth.js";

async function call(path, { method = "GET", body, query } = {}, retried = false) {
  const url = new URL(`${API_BASE}${path}`);
  if (query) for (const [k, v] of Object.entries(query)) {
    if (v !== undefined && v !== null) url.searchParams.set(k, v);
  }
  const token = await getAccessToken();
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(body !== undefined ? { "Content-Type": "application/json" } : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  if (res.status === 401 && !retried) return call(path, { method, body, query }, true);
  if (res.status === 204) return null;
  const text = await res.text();
  const json = text ? JSON.parse(text) : null;
  if (!res.ok) {
    const msg = json?.error?.message || res.statusText;
    const err = new Error(`Spotify ${res.status}: ${msg}`);
    err.status = res.status;
    err.body = json;
    throw err;
  }
  return json;
}

export async function getMe() {
  return call("/me");
}

export async function listDevices() {
  const res = await call("/me/player/devices");
  return res?.devices || [];
}

export async function transferPlayback(deviceId, play = false) {
  return call("/me/player", {
    method: "PUT",
    body: { device_ids: [deviceId], play },
  });
}

export async function play({ deviceId, uri, positionMs }) {
  return call("/me/player/play", {
    method: "PUT",
    query: deviceId ? { device_id: deviceId } : undefined,
    body: {
      uris: [uri],
      position_ms: Math.max(0, Math.floor(positionMs || 0)),
    },
  });
}

export async function pause(deviceId) {
  return call("/me/player/pause", {
    method: "PUT",
    query: deviceId ? { device_id: deviceId } : undefined,
  });
}

// Best-effort: pick the active device, else the first non-restricted device.
export function pickDevice(devices) {
  if (!devices?.length) return null;
  const active = devices.find((d) => d.is_active);
  if (active) return active;
  const usable = devices.find((d) => !d.is_restricted);
  return usable || devices[0];
}
