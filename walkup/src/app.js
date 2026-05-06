// Entry point. Wires DOM events to auth + playback + roster modules.
import { beginLogin, handleCallback, isAuthed, logout } from "./auth.js";
import * as roster from "./roster.js";
import * as playback from "./playback.js";
import { Mode } from "./playback.js";
import * as spotify from "./spotify.js";

const $ = (sel) => document.querySelector(sel);

const els = {
  login: $("#login-view"),
  loginBtn: $("#login-btn"),
  loginError: $("#login-error"),
  rosterView: $("#roster-view"),
  rosterList: $("#roster"),
  modeToggle: $("#mode-toggle"),
  settingsBtn: $("#settings-btn"),
  settings: $("#settings"),
  deviceBanner: $("#device-banner"),
  deviceSelect: $("#device-select"),
  refreshDevices: $("#refresh-devices"),
  rosterJson: $("#roster-json"),
  rosterSave: $("#roster-save"),
  rosterReset: $("#roster-reset"),
  rosterStatus: $("#roster-status"),
  logoutBtn: $("#logout-btn"),
  nowPlaying: $("#now-playing"),
  npPlayer: $("#now-playing .np-player"),
  npTrack: $("#now-playing .np-track"),
  npProgress: $("#now-playing .np-progress span"),
  npStop: $("#np-stop"),
};

let progressTimer = null;

async function init() {
  try {
    const consumed = await handleCallback();
    if (consumed && !isAuthed()) {
      // Callback returned but no token landed — show login with error.
      throw new Error("Login completed but token missing.");
    }
  } catch (e) {
    showLoginError(e.message);
  }

  if (!isAuthed()) return showLogin();
  showRoster();
}

function showLogin() {
  els.login.hidden = false;
  els.rosterView.hidden = true;
}

function showLoginError(msg) {
  els.loginError.textContent = msg;
  els.loginError.hidden = false;
}

function showRoster() {
  els.login.hidden = true;
  els.rosterView.hidden = false;
  refreshModeToggle();
  renderRoster();
  refreshDeviceBanner();
}

function refreshModeToggle() {
  const mode = playback.getMode();
  els.modeToggle.setAttribute("aria-pressed", mode === Mode.Sample ? "true" : "false");
  els.modeToggle.textContent = mode === Mode.Sample ? "Sample" : "Walk-up";
  els.modeToggle.title =
    mode === Mode.Sample
      ? "Sample mode: auto-pauses 10s after the cue point."
      : "Walk-up mode: plays from cue point until stopped.";
}

function renderRoster() {
  const data = roster.loadRoster();
  els.rosterList.innerHTML = "";
  for (const p of roster.sorted(data.players)) {
    const li = document.createElement("li");
    li.className = "player";
    li.dataset.id = p.id;
    if (!roster.isConfigured(p)) li.classList.add("unconfigured");
    li.innerHTML = `
      <div class="jersey">${escapeHtml(p.jersey || "—")}</div>
      <div class="meta">
        <div class="name">${escapeHtml(p.name)}</div>
        <div class="track">${
          roster.isConfigured(p)
            ? `${escapeHtml(p.trackName || "—")} · ${escapeHtml(p.artist || "")}`
            : "+ Add song in settings"
        }</div>
      </div>
      <div class="cue">${roster.isConfigured(p) ? roster.formatCue(p.startMs) : ""}</div>
    `;
    li.addEventListener("click", () => onCardTap(p.id));
    els.rosterList.appendChild(li);
  }
}

async function onCardTap(playerId) {
  const data = roster.loadRoster();
  const player = data.players.find((p) => p.id === playerId);
  if (!player) return;

  const state = playback.getState();
  if (state.currentPlayerId === playerId) {
    await stopAndUI();
    return;
  }
  if (!roster.isConfigured(player)) {
    flashBanner(`${player.name} has no track configured. Add one in Settings → Roster.`);
    return;
  }

  setCardPlaying(playerId);
  showNowPlaying(player);
  try {
    await playback.playForPlayer(player);
  } catch (e) {
    setCardPlaying(null);
    hideNowPlaying();
    flashBanner(e.message);
  }
}

function setCardPlaying(playerId) {
  for (const card of els.rosterList.querySelectorAll(".player")) {
    card.classList.toggle("playing", card.dataset.id === playerId);
  }
}

function showNowPlaying(player) {
  els.npPlayer.textContent = `#${player.jersey} ${player.name}`;
  els.npTrack.textContent = `${player.trackName || ""} · ${player.artist || ""}`;
  els.npProgress.style.width = "0%";
  els.nowPlaying.hidden = false;

  clearInterval(progressTimer);
  progressTimer = setInterval(() => {
    const st = playback.getState();
    if (!st.currentPlayerId) {
      clearInterval(progressTimer);
      hideNowPlaying();
      setCardPlaying(null);
      return;
    }
    const dur = playback.getMode() === Mode.Sample
      ? (player.sampleDurationMs || 10000)
      : 30000; // visual progress horizon for walk-up mode
    const elapsed = Date.now() - st.startedAt;
    const pct = Math.min(100, (elapsed / dur) * 100);
    els.npProgress.style.width = `${pct}%`;
  }, 200);
}

function hideNowPlaying() {
  els.nowPlaying.hidden = true;
  els.npProgress.style.width = "0%";
}

async function stopAndUI() {
  try { await playback.pauseCurrent(); } catch (e) { flashBanner(e.message); }
  setCardPlaying(null);
  hideNowPlaying();
}

function flashBanner(msg) {
  els.deviceBanner.textContent = msg;
  els.deviceBanner.hidden = false;
  clearTimeout(flashBanner._t);
  flashBanner._t = setTimeout(() => { els.deviceBanner.hidden = true; }, 6000);
}

async function refreshDeviceBanner() {
  try {
    const { devices, chosen } = await playback.resolveDevice();
    if (!devices.length) {
      flashBanner("No Spotify device detected. Open Spotify on your phone and play any track briefly.");
    } else if (chosen) {
      els.deviceBanner.textContent = `Routing to: ${chosen.name} (${chosen.type})`;
      els.deviceBanner.hidden = false;
      clearTimeout(flashBanner._t);
      flashBanner._t = setTimeout(() => { els.deviceBanner.hidden = true; }, 4000);
    }
  } catch (e) {
    flashBanner(e.message);
  }
}

async function populateDeviceSelect() {
  els.deviceSelect.innerHTML = "<option value=\"\">Auto (active device)</option>";
  try {
    const devices = await spotify.listDevices();
    const preferred = playback.getPreferredDeviceId();
    for (const d of devices) {
      const opt = document.createElement("option");
      opt.value = d.id;
      opt.textContent = `${d.name} · ${d.type}${d.is_active ? " (active)" : ""}`;
      if (d.id === preferred) opt.selected = true;
      els.deviceSelect.appendChild(opt);
    }
  } catch (e) {
    flashBanner(e.message);
  }
}

function openSettings() {
  els.rosterJson.value = JSON.stringify(roster.loadRoster(), null, 2);
  els.rosterStatus.textContent = "";
  els.rosterStatus.className = "status";
  populateDeviceSelect();
  els.settings.showModal();
}

// --- wire up DOM ---
els.loginBtn.addEventListener("click", async () => {
  els.loginError.hidden = true;
  try { await beginLogin(); }
  catch (e) { showLoginError(e.message); }
});

els.modeToggle.addEventListener("click", () => {
  const next = playback.getMode() === Mode.Sample ? Mode.WalkUp : Mode.Sample;
  playback.setMode(next);
  refreshModeToggle();
});

els.settingsBtn.addEventListener("click", openSettings);

els.deviceSelect.addEventListener("change", () => {
  playback.setPreferredDeviceId(els.deviceSelect.value || null);
});
els.refreshDevices.addEventListener("click", populateDeviceSelect);

els.rosterSave.addEventListener("click", () => {
  try {
    const parsed = JSON.parse(els.rosterJson.value);
    roster.saveRoster(parsed);
    els.rosterStatus.textContent = "Saved.";
    els.rosterStatus.className = "status ok";
    renderRoster();
  } catch (e) {
    els.rosterStatus.textContent = e.message;
    els.rosterStatus.className = "status err";
  }
});

els.rosterReset.addEventListener("click", () => {
  const fresh = roster.resetRoster();
  els.rosterJson.value = JSON.stringify(fresh, null, 2);
  els.rosterStatus.textContent = "Reset to default.";
  els.rosterStatus.className = "status ok";
  renderRoster();
});

els.logoutBtn.addEventListener("click", () => {
  logout();
  els.settings.close();
  showLogin();
});

els.npStop.addEventListener("click", stopAndUI);

// Refresh device list when the tab regains focus (likely after the user
// woke up Spotify on their phone).
window.addEventListener("focus", () => {
  if (!els.rosterView.hidden) refreshDeviceBanner();
});

function escapeHtml(s) {
  return String(s ?? "").replace(/[&<>"']/g, (c) => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]
  ));
}

init();
