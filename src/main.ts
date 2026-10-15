import { Logger } from "./logger";
import { makeCompatibilityReport, type CompatibilityReport } from "./report";
import { parsePe, PeError } from "./pe";
import { reportCompatibility, EXPECTED_FILES } from "./compat";

const log = new Logger();
const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const logEl = $<HTMLPreElement>("log");
const statusEl = $("status");

log.onEntry((e) => {
  logEl.textContent += `${e.level.toUpperCase().padEnd(5)} ${e.message}\n`;
});

window.addEventListener("error", (ev) => log.error(`Uncaught: ${ev.message}`));
window.addEventListener("unhandledrejection", (ev) => log.error(`Unhandled rejection: ${String(ev.reason)}`));

let files: File[] = [];
let report: CompatibilityReport | null = null;
const exportButton = $<HTMLButtonElement>("export");
exportButton.disabled = true;

function relPath(f: File): string {
  return (f as File & { webkitRelativePath?: string }).webkitRelativePath || f.name;
}

async function analyze(): Promise<void> {
  report = null;
  exportButton.disabled = true;
  const exe = files.find((f) => EXPECTED_FILES.some((n) => f.name.toLowerCase() === n.toLowerCase()));
  if (!exe) {
    statusEl.textContent = "MBAA.exe not found in the selected folder.";
    log.error(`Missing expected file(s): ${EXPECTED_FILES.join(", ")}`);
    return;
  }
  try {
    log.info(`Parsing ${relPath(exe)} (${exe.size} bytes) locally; nothing is uploaded.`);
    const parsed = parsePe(await exe.arrayBuffer());
    reportCompatibility(parsed, log);
    report = makeCompatibilityReport(parsed);
    exportButton.disabled = false;
    statusEl.textContent = "Executable parsed (static analysis only). Execution is not implemented yet.";
  } catch (e) {
    statusEl.textContent = "Failed to parse executable.";
    log.error(e instanceof PeError ? `Invalid executable: ${e.message}` : `Unexpected error: ${String(e)}`);
  }
}

$<HTMLInputElement>("picker").addEventListener("change", (ev) => {
  files = Array.from((ev.target as HTMLInputElement).files ?? []);
  logEl.textContent = "";
  log.entries.length = 0;
  $("count").textContent = `${files.length} file(s) selected`;
  log.info(`Selected ${files.length} file(s).`);
  void analyze();
});

exportButton.addEventListener("click", () => {
  if (!report) return;
  const url = URL.createObjectURL(new Blob([JSON.stringify(report, null, 2)], { type: "application/json" }));
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = "mbaacc-compatibility-report.json";
  anchor.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
});

$<HTMLButtonElement>("run").addEventListener("click", () => {
  log.error("Execution backend (BottleShip) is not integrated yet. See docs/COMPATIBILITY.md.");
});

$("copy").addEventListener("click", () => {
  navigator.clipboard.writeText(log.toText()).catch((e) => log.error(`Could not copy log: ${String(e)}`));
});

log.info(`WebGPU: ${"gpu" in navigator ? "available" : "NOT available"}`);
log.info(`SharedArrayBuffer: ${typeof SharedArrayBuffer !== "undefined" ? "available" : "NOT available"}`);
log.info(`OPFS: ${navigator.storage && "getDirectory" in navigator.storage ? "available" : "NOT available"}`);
