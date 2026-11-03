const pad = (n) => String(n).padStart(2, "0");

// A duration in short form, like `5h 03m 22s`, leaving out leading zero units
// (mirrors `PanicWeb.RunFormat.duration/1`)
export function formatDuration(totalSeconds) {
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = totalSeconds % 60;

  if (h > 0) return `${h}h ${pad(m)}m ${pad(s)}s`;
  if (m > 0) return `${m}m ${pad(s)}s`;
  return `${s}s`;
}

// Time elapsed, to the minute, like `5h 03m` (mirrors
// `PanicWeb.RunFormat.elapsed/2`)
export function formatElapsed(totalSeconds) {
  if (totalSeconds < 60) return "under a minute";

  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);

  return h > 0 ? `${h}h ${pad(m)}m` : `${m}m`;
}
