/* eslint-disable */
import * as admin from "firebase-admin";

export type CalendarMatch = Record<string, any> & {id: string};
export type CalendarTeam = Record<string, any> & {id: string};

export interface CalendarInput {
  seasonId: string;
  matches: CalendarMatch[];
  teams: CalendarTeam[];
  clubs?: CalendarTeam[];
  division?: "A" | "B";
  teamId?: string;
  baseUrl: string;
  generatedAt?: Date;
}

const text = (value: unknown): string => String(value ?? "").trim();

export function escapeIcs(value: unknown): string {
  return text(value)
    .replace(/\\/g, "\\\\")
    .replace(/\r\n|\r|\n/g, "\\n")
    .replace(/;/g, "\\;")
    .replace(/,/g, "\\,");
}

export function foldIcsLine(line: string): string {
  const chunks: string[] = [];
  let current = "";
  let bytes = 0;
  for (const character of line) {
    const size = Buffer.byteLength(character, "utf8");
    if (bytes + size > (chunks.length ? 74 : 75)) {
      chunks.push(current);
      current = character;
      bytes = size;
    } else {
      current += character;
      bytes += size;
    }
  }
  chunks.push(current);
  return chunks.join("\r\n ");
}

function timestamp(value: any): Date | null {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === "function") return value.toDate();
  if (typeof value._seconds === "number") return new Date(value._seconds * 1000);
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function utc(value: Date): string {
  return value.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
}

function localDateTime(match: CalendarMatch): string | null {
  const date = text(match.date || match.datum);
  const time = text(match.kickoffTime || match.time || match.kickoff || "14:30");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !/^\d{2}:\d{2}$/.test(time)) return null;
  return `${date.replace(/-/g, "")}T${time.replace(":", "")}00`;
}

function addHours(local: string, hours: number): string {
  const match = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})$/.exec(local)!;
  const date = new Date(Date.UTC(+match[1], +match[2] - 1, +match[3], +match[4], +match[5], +match[6]));
  date.setUTCHours(date.getUTCHours() + hours);
  return date.toISOString().replace(/[-:]/g, "").slice(0, 15);
}

function teamKey(value: unknown): string {
  return text(value).toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .replace(/[’']/g, "").replace(/[^a-z0-9]/g, "");
}

function matchTeamId(match: CalendarMatch, side: "home" | "away"): string {
  const slugs = match.teamSlugs || {};
  return text(match[`${side}TeamSlug`] || match[`${side}Slug`] || slugs[side] ||
    match[`${side}TeamId`] || match[`${side}Team`]);
}

function teamMatches(match: CalendarMatch, teamId: string): boolean {
  const wanted = teamKey(teamId);
  return [matchTeamId(match, "home"), matchTeamId(match, "away"),
    match.homeTeam, match.awayTeam].some((value) => teamKey(value) === wanted);
}

function statusOf(match: CalendarMatch): string {
  const status = text(match.status).toLowerCase();
  return status === "cancelled" ? "canceled" : status || "scheduled";
}

function statusLabel(status: string): string {
  return ({scheduled: "Gepland", postponed: "Uitgesteld", canceled: "Afgelast",
    finished: "Afgelopen", abandoned: "Gestaakt"} as Record<string, string>)[status] || status;
}

function field(source: any, ...names: string[]): string {
  for (const name of names) {
    const value = text(source?.[name]);
    if (value) return value;
  }
  return "";
}

function venueFields(source: any): Record<string, string> {
  if (!source) return {};
  const nested = source.venue || source.location || {};
  return {
    venueName: field(source, "venueName", "accommodationName") || field(nested, "venueName", "accommodationName"),
    venueAddress: field(source, "venueAddress", "address") || field(nested, "venueAddress", "address"),
    venuePostalCode: field(source, "venuePostalCode", "postalCode") || field(nested, "venuePostalCode", "postalCode"),
    venueCity: field(source, "venueCity", "city") || field(nested, "venueCity", "city"),
  };
}

function mergeVenue(...sources: any[]): Record<string, string> {
  const result: Record<string, string> = {};
  for (const source of sources) {
    for (const [key, value] of Object.entries(venueFields(source))) {
      if (value) result[key] = value;
    }
  }
  return result;
}

function locationFor(match: CalendarMatch, home?: CalendarTeam, club?: CalendarTeam): string {
  const source = mergeVenue(club, home, match);
  const name = field(source, "venueName", "accommodationName");
  const address = field(source, "venueAddress", "address");
  const postal = field(source, "venuePostalCode", "postalCode");
  const city = field(source, "venueCity", "city");
  return [name, [address, [postal, city].filter(Boolean).join(" ")].filter(Boolean).join(", ")]
    .filter(Boolean).join(", ");
}

function sequence(match: CalendarMatch): number {
  const explicit = Number(match.sequence);
  if (Number.isInteger(explicit) && explicit >= 0) return explicit;
  const updated = timestamp(match.updatedAt || match.lastModified);
  const created = timestamp(match.createdAt);
  if (!updated) return 0;
  if (!created) return Math.floor(updated.getTime() / 1000);
  return Math.max(0, Math.floor((updated.getTime() - created.getTime()) / 1000));
}

export function buildCalendar(input: CalendarInput): string {
  const now = input.generatedAt || new Date();
  const teams = new Map<string, CalendarTeam>();
  const clubs = new Map<string, CalendarTeam>();
  for (const team of input.teams) {
    for (const key of [team.id, team.teamId, team.name, team.displayName]) {
      if (key) teams.set(teamKey(key), team);
    }
  }
  for (const club of input.clubs || []) {
    for (const key of [club.id, club.clubId, club.teamId, club.name]) {
      if (key) clubs.set(teamKey(key), club);
    }
  }
  const selected = input.matches.filter((match) => {
    if (input.division && text(match.division).toUpperCase() !== input.division) return false;
    return !input.teamId || teamMatches(match, input.teamId);
  }).sort((a, b) => text(a.date).localeCompare(text(b.date)) || text(a.kickoffTime).localeCompare(text(b.kickoffTime)));

  const lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//DerdeDiv//Wedstrijdprogramma//NL",
    "CALSCALE:GREGORIAN", "METHOD:PUBLISH", "X-WR-CALNAME:DerdeDiv wedstrijdprogramma",
    "X-WR-TIMEZONE:Europe/Amsterdam", "BEGIN:VTIMEZONE", "TZID:Europe/Amsterdam",
    "BEGIN:DAYLIGHT", "TZOFFSETFROM:+0100", "TZOFFSETTO:+0200", "TZNAME:CEST",
    "DTSTART:19700329T020000", "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU", "END:DAYLIGHT",
    "BEGIN:STANDARD", "TZOFFSETFROM:+0200", "TZOFFSETTO:+0100", "TZNAME:CET",
    "DTSTART:19701025T030000", "RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU", "END:STANDARD", "END:VTIMEZONE"];

  for (const match of selected) {
    const start = localDateTime(match);
    if (!start) continue;
    const status = statusOf(match);
    const homeName = text(match.homeTeam || match.homeTeamName || match.home);
    const awayName = text(match.awayTeam || match.awayTeamName || match.away);
    const scored = match.homeScore != null && match.awayScore != null;
    let summary = scored ? `${homeName} ${match.homeScore} – ${match.awayScore} ${awayName}` : `${homeName} – ${awayName}`;
    if (status === "canceled") summary = `[Afgelast] ${summary}`;
    if (status === "postponed") summary = `[Uitgesteld] ${summary}`;
    if (status === "abandoned") summary = `[Gestaakt] ${summary}`;
    const division = text(match.division).toUpperCase();
    const url = `${input.baseUrl.replace(/\/$/, "")}/#/programma?wedstrijd=${encodeURIComponent(match.id)}`;
    const date = text(match.date);
    const time = text(match.kickoffTime || match.time || match.kickoff);
    const description = [`Competitie: Derde Divisie ${division}`, `Speelronde: ${match.round ?? match.speelronde ?? "-"}`,
      `Thuisclub: ${homeName}`, `Uitclub: ${awayName}`, `Datum en tijd: ${date} ${time}`,
      `Status: ${statusLabel(status)}`, ...(scored ? [`Uitslag: ${match.homeScore} - ${match.awayScore}`] : []), `Meer informatie: ${url}`].join("\n");
    const home = teams.get(teamKey(matchTeamId(match, "home"))) || teams.get(teamKey(homeName));
    const explicitClubId = text(home?.clubId);
    const fallbackClubId = text(home?.teamId || home?.id || matchTeamId(match, "home"));
    const club = explicitClubId ? clubs.get(teamKey(explicitClubId)) :
      clubs.get(teamKey(fallbackClubId)) || clubs.get(teamKey(homeName));
    const location = locationFor(match, home, club);
    const modified = timestamp(match.updatedAt || match.lastModified || match.createdAt) || now;
    lines.push("BEGIN:VEVENT", `UID:${escapeIcs(match.id)}@derdediv.nl`, `DTSTAMP:${utc(now)}`,
      `DTSTART;TZID=Europe/Amsterdam:${start}`, `DTEND;TZID=Europe/Amsterdam:${addHours(start, 2)}`,
      `SUMMARY:${escapeIcs(summary)}`, `DESCRIPTION:${escapeIcs(description)}`);
    if (location) lines.push(`LOCATION:${escapeIcs(location)}`);
    lines.push(`URL:${escapeIcs(url)}`, `STATUS:${status === "canceled" ? "CANCELLED" : "CONFIRMED"}`,
      `SEQUENCE:${sequence(match)}`, `LAST-MODIFIED:${utc(modified)}`, "END:VEVENT");
  }
  lines.push("END:VCALENDAR");
  return lines.map(foldIcsLine).join("\r\n") + "\r\n";
}

export async function loadCalendarData(db: admin.firestore.Firestore) {
  const current = await db.doc("system/current_season").get();
  const seasonId = text(current.data()?.seasonId || current.data()?.id);
  if (!seasonId) throw new Error("Actief seizoen ontbreekt in system/current_season");
  const season = db.collection("seasons").doc(seasonId);
  const [matches, teams, clubs] = await Promise.all([
    season.collection("matches").get(),
    season.collection("teams").get(),
    db.collection("teams").get(),
  ]);
  return {seasonId, matches: matches.docs.map((doc) => ({id: doc.id, ...doc.data()})),
    teams: teams.docs.map((doc) => ({id: doc.id, ...doc.data()})),
    clubs: clubs.docs.map((doc) => ({id: doc.id, ...doc.data()}))};
}
