/**
 * IANA 时区墙钟时间 ↔ UTC 换算,与 App 端 P2.10 语义一致:
 * events.start_at 存 UTC,events.timezone 存 IANA 名;用户按活动时区录墙钟时间。
 * 仅用 Intl 实现,不引第三方时区库。
 */

export const COMMON_TIMEZONES = [
  "Asia/Shanghai",
  "Asia/Taipei",
  "Asia/Hong_Kong",
  "Asia/Singapore",
  "Asia/Tokyo",
  "America/Los_Angeles",
  "America/New_York",
  "America/Vancouver",
  "Europe/London",
  "Europe/Paris",
  "Australia/Sydney",
  "UTC",
];

export function isValidTimeZone(tz: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

function wallPartsInZone(utc: Date, tz: string) {
  const dtf = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  });
  const p = Object.fromEntries(
    dtf
      .formatToParts(utc)
      .filter((x) => x.type !== "literal")
      .map((x) => [x.type, x.value]),
  );
  return {
    y: +p.year,
    m: +p.month,
    d: +p.day,
    h: p.hour === "24" ? 0 : +p.hour,
    min: +p.minute,
    s: +p.second,
  };
}

function zoneOffsetMs(tz: string, utc: Date): number {
  const w = wallPartsInZone(utc, tz);
  return Date.UTC(w.y, w.m - 1, w.d, w.h, w.min, w.s) - utc.getTime();
}

const pad = (n: number) => String(n).padStart(2, "0");

/** 活动时区墙钟(datetime-local 值 `YYYY-MM-DDTHH:mm`)→ UTC ISO */
export function zonedLocalToUtcIso(local: string, tz: string): string {
  const [datePart, timePart] = local.split("T");
  const [y, m, d] = datePart.split("-").map(Number);
  const [h, min] = timePart.split(":").map(Number);
  const guess = Date.UTC(y, m - 1, d, h, min);
  let ts = guess - zoneOffsetMs(tz, new Date(guess));
  ts = guess - zoneOffsetMs(tz, new Date(ts)); // DST 边界二次校准
  return new Date(ts).toISOString();
}

/** UTC ISO → 活动时区墙钟(datetime-local 值) */
export function utcIsoToZonedLocal(iso: string, tz: string): string {
  const w = wallPartsInZone(new Date(iso), tz);
  return `${w.y}-${pad(w.m)}-${pad(w.d)}T${pad(w.h)}:${pad(w.min)}`;
}

/** UTC ISO 在活动时区下的日期 `yyyy-MM-dd`(event_overrides.occurrence_date 的键) */
export function occurrenceDateInZone(iso: string, tz: string): string {
  const w = wallPartsInZone(new Date(iso), tz);
  return `${w.y}-${pad(w.m)}-${pad(w.d)}`;
}

/** UTC ISO 按活动时区显示 `yyyy/MM/dd HH:mm` */
export function fmtWallTime(iso: string, tz: string): string {
  const w = wallPartsInZone(new Date(iso), tz);
  return `${w.y}/${pad(w.m)}/${pad(w.d)} ${pad(w.h)}:${pad(w.min)}`;
}

/**
 * FREQ=WEEKLY 展开:在活动时区按 +7 个日历日、保持墙钟时刻(与 App/服务端一致,跨 DST 安全)。
 * 返回自 `from` 起的未来 `count` 个场次 UTC ISO(含未来的首场)。
 */
export function expandWeeklyUtc(
  startIso: string,
  tz: string,
  count: number,
  from = new Date(),
): string[] {
  const w = wallPartsInZone(new Date(startIso), tz);
  const out: string[] = [];
  for (let i = 0; out.length < count && i < 520; i++) {
    const dd = new Date(Date.UTC(w.y, w.m - 1, w.d + 7 * i));
    const local = `${dd.getUTCFullYear()}-${pad(dd.getUTCMonth() + 1)}-${pad(dd.getUTCDate())}T${pad(w.h)}:${pad(w.min)}`;
    const iso = zonedLocalToUtcIso(local, tz);
    if (new Date(iso) >= from) out.push(iso);
  }
  return out;
}
