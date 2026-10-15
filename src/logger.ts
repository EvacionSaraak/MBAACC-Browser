export type LogLevel = "info" | "warn" | "error";

export interface LogEntry {
  time: Date;
  level: LogLevel;
  message: string;
}

export class Logger {
  readonly entries: LogEntry[] = [];
  private listeners: Array<(e: LogEntry) => void> = [];

  onEntry(fn: (e: LogEntry) => void): void {
    this.listeners.push(fn);
  }

  log(level: LogLevel, message: string): void {
    const entry = { time: new Date(), level, message };
    this.entries.push(entry);
    for (const l of this.listeners) l(entry);
  }

  info(m: string): void { this.log("info", m); }
  warn(m: string): void { this.log("warn", m); }
  error(m: string): void { this.log("error", m); }

  toText(): string {
    return this.entries
      .map((e) => `[${e.time.toISOString()}] ${e.level.toUpperCase()} ${e.message}`)
      .join("\n");
  }
}
