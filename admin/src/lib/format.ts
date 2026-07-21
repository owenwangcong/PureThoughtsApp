/** 时间显示统一用浏览器本地时区;后台是内部工具,无需多时区切换。 */

const dt = new Intl.DateTimeFormat("zh-TW", {
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  hour12: false,
});

const d = new Intl.DateTimeFormat("zh-TW", {
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

export function fmtDateTime(iso: string | null | undefined): string {
  if (!iso) return "—";
  return dt.format(new Date(iso));
}

export function fmtDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  return d.format(new Date(iso));
}

/** datetime-local 输入值(本地墙钟)→ ISO(UTC)字符串 */
export function localInputToIso(value: string): string {
  return new Date(value).toISOString();
}
