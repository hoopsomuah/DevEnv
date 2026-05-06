// Playback controller: orchestrates calls to the Web API + Connect target device.
// Tracks current player and sample-mode auto-pause timer.
import * as spotify from "./spotify.js";

const MODE_KEY = "walkup.mode";
const DEVICE_KEY = "walkup.deviceId";

export const Mode = Object.freeze({ WalkUp: "walkup", Sample: "sample" });

export function getMode() {
  const m = localStorage.getItem(MODE_KEY);
  return m === Mode.Sample ? Mode.Sample : Mode.WalkUp;
}
export function setMode(mode) {
  localStorage.setItem(MODE_KEY, mode);
}

export function getPreferredDeviceId() {
  return localStorage.getItem(DEVICE_KEY) || null;
}
export function setPreferredDeviceId(id) {
  if (id) localStorage.setItem(DEVICE_KEY, id);
  else localStorage.removeItem(DEVICE_KEY);
}

let state = {
  currentPlayerId: null,
  sampleTimer: null,
  startedAt: 0,
  player: null, // last-played player object, for UI
};

export function getState() {
  return { ...state };
}

export async function resolveDevice() {
  const devices = await spotify.listDevices();
  const preferredId = getPreferredDeviceId();
  const preferred = devices.find((d) => d.id === preferredId);
  return { devices, chosen: preferred || spotify.pickDevice(devices) };
}

export async function playForPlayer(player) {
  if (!player?.trackUri) throw new Error(`${player?.name || "Player"} has no track configured.`);
  clearSampleTimer();

  const { chosen } = await resolveDevice();
  if (!chosen) {
    throw new Error(
      "No active Spotify device found. Open Spotify on your phone, play any track briefly, then try again."
    );
  }

  await spotify.play({
    deviceId: chosen.id,
    uri: player.trackUri,
    positionMs: player.startMs || 0,
  });

  state.currentPlayerId = player.id;
  state.player = player;
  state.startedAt = Date.now();

  if (getMode() === Mode.Sample) {
    const dur = player.sampleDurationMs || 10000;
    state.sampleTimer = setTimeout(() => {
      pauseCurrent().catch(() => {});
    }, dur);
  }
  return chosen;
}

export async function pauseCurrent() {
  clearSampleTimer();
  const { chosen } = await resolveDevice().catch(() => ({ chosen: null }));
  try {
    await spotify.pause(chosen?.id);
  } catch (e) {
    if (e.status !== 403 && e.status !== 404) throw e;
  }
  state.currentPlayerId = null;
}

function clearSampleTimer() {
  if (state.sampleTimer) {
    clearTimeout(state.sampleTimer);
    state.sampleTimer = null;
  }
}
