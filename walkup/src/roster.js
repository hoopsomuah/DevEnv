// Roster CRUD against localStorage. Single JSON blob, schema per PRD §6.5.
const KEY = "walkup.roster";

export const DEFAULT_ROSTER = {
  team: "The Boom Squad",
  players: [
    {
      id: "lucy",
      jersey: "00",
      name: "Lucy",
      trackUri: "spotify:track:REPLACE_WITH_TRACK_URI",
      trackName: "Also Sprach Zarathustra",
      artist: "Phish",
      startMs: 469000,
      sampleDurationMs: 10000,
    },
    {
      id: "eva",
      jersey: "—",
      name: "Eva",
      trackUri: null,
      trackName: null,
      artist: null,
      startMs: 0,
      sampleDurationMs: 10000,
    },
  ],
};

export function loadRoster() {
  const raw = localStorage.getItem(KEY);
  if (!raw) return structuredClone(DEFAULT_ROSTER);
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || !Array.isArray(parsed.players)) throw new Error("malformed");
    return parsed;
  } catch {
    return structuredClone(DEFAULT_ROSTER);
  }
}

export function saveRoster(roster) {
  validate(roster);
  localStorage.setItem(KEY, JSON.stringify(roster));
}

export function resetRoster() {
  localStorage.removeItem(KEY);
  return loadRoster();
}

export function isConfigured(player) {
  return Boolean(
    player?.trackUri &&
      player.trackUri.startsWith("spotify:track:") &&
      !player.trackUri.includes("REPLACE")
  );
}

export function formatCue(ms) {
  const s = Math.max(0, Math.floor((ms || 0) / 1000));
  const m = Math.floor(s / 60);
  return `${m}:${String(s % 60).padStart(2, "0")}`;
}

// Roster ordering rule from PRD §4.1: jersey ascending, with non-numeric (00, —) handled deterministically.
// 00 is treated as -1 (first), non-numeric like "—" goes to the end.
export function sorted(players) {
  return [...players].sort((a, b) => rank(a.jersey) - rank(b.jersey));
}

function rank(j) {
  if (j === "00") return -1;
  const n = Number(j);
  if (Number.isFinite(n)) return n;
  return 1e6;
}

function validate(roster) {
  if (!roster || typeof roster !== "object") throw new Error("Roster must be an object.");
  if (!Array.isArray(roster.players)) throw new Error("roster.players must be an array.");
  const ids = new Set();
  for (const p of roster.players) {
    if (!p.id) throw new Error("Each player needs an id.");
    if (ids.has(p.id)) throw new Error(`Duplicate player id: ${p.id}`);
    ids.add(p.id);
    if (!p.name) throw new Error(`Player ${p.id} missing name.`);
    if (typeof p.startMs !== "number" || p.startMs < 0) {
      throw new Error(`Player ${p.id}: startMs must be a non-negative number.`);
    }
  }
}
