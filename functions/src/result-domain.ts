/* eslint-disable max-len, require-jsdoc, @typescript-eslint/no-explicit-any */
import {createHash} from "crypto";
import {teams} from "./season-teams";

export const ACTIVE_SEASON = "2026-2027";
export type Data = Record<string, any>;
export function integer(value: any): number {
  return Number.isFinite(Number(value)) ? Math.trunc(Number(value)) : 0;
}
export function uid(p: Data): string {
  return String(p.gebruikerId ?? p.userId ?? p.uid ?? "").trim();
}
export function division(m: Data): string {
  const raw = String(m.division ?? m.divisie ?? m.competitie ?? "").toUpperCase();
  if (["A", "DDA", "3A", "DERDE DIVISIE A"].includes(raw)) return "A";
  if (["B", "DDB", "3B", "DERDE DIVISIE B"].includes(raw)) return "B";
  throw new Error("Invalid match division");
}
export function score(p: Data, home: boolean): number {
  const keys = home ? ["scoreThuis", "homeScore", "thuisScore", "homeGoals", "voorspellingThuis", "thuis", "home", "goalsHome", "predHome"] :
    ["scoreUit", "awayScore", "uitScore", "awayGoals", "voorspellingUit", "uit", "away", "goalsAway", "predAway"];
  for (const key of keys) if (p[key] != null && /^\d+$/.test(String(p[key]))) return integer(p[key]);
  throw new Error("Missing or invalid prediction score");
}
export function points(ph: number, pa: number, h: number, a: number): number {
  if (ph === h && pa === a) return 10;
  if (h === a && ph === pa) return 7;
  return (h !== a && Math.sign(ph-pa) === Math.sign(h-a) ? 5 : 0) + (ph === h ? 2 : 0) + (pa === a ? 2 : 0);
}
export function result(m: Data): [number, number] | null {
  if (m.status !== "finished") return null;
  const h = m.homeScore ?? m.uitslagThuis; const a = m.awayScore ?? m.uitslagUit;
  if (h == null || a == null || !/^\d+$/.test(String(h)) || !/^\d+$/.test(String(a))) throw new Error("Invalid finished result");
  return [integer(h), integer(a)];
}
function key(value: any): string {
  return String(value ?? "").toUpperCase().replace(/['’`´\s/._-]/g, "").replace(/&/g, "EN");
}
export function team(m: Data, home: boolean): {id: string; name: string; division: string} {
  const names = home ? [m.homeTeamSlug, m.homeTeamCode, m.homeTeamName, m.homeTeam, m.thuisteam] :
    [m.awayTeamSlug, m.awayTeamCode, m.awayTeamName, m.awayTeam, m.uitteam];
  const found = teams.find((t) => names.some((n) => n && [t.id, t.name, ...t.aliases].some((a) => key(n) === key(a))));
  if (!found || found.division !== division(m)) throw new Error("Unknown team or wrong division");
  return found;
}
export function millis(v: any): number | null {
  if (v?.toMillis) return v.toMillis();
  const parsed = v instanceof Date ? v.getTime() : typeof v === "string" ? Date.parse(v) : NaN;
  return Number.isFinite(parsed) ? parsed : null;
}
export function matchDate(m: Data): number | null {
  return millis(m.scheduledAt ?? m.kickoff ?? m.timestamp ?? m.datum ?? m.date);
}
const localParts = (ms: number) => Object.fromEntries(new Intl.DateTimeFormat("en-GB", {
  timeZone: "Europe/Amsterdam", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23",
}).formatToParts(new Date(ms)).map((p) => [p.type, p.value]));
export function deadline(m: Data): number | null {
  const ms = matchDate(m); if (ms == null) return null;
  const p = localParts(ms);
  const noonUtc = Date.UTC(+p.year, +p.month-1, +p.day, 12);
  const n = localParts(noonUtc);
  return noonUtc - ((+n.hour-12)*60 + +n.minute)*60000;
}
export function eligible(p: Data, m: Data): boolean {
  const end = deadline(m); const submitted = millis(p.timestamp);
  return end == null || (submitted != null && submitted <= end);
}
export function fingerprint(m: Data): string {
  const date = matchDate(m); const p = date == null ? null : localParts(date);
  return createHash("sha256").update(JSON.stringify([
    division(m), m.processingRequest ?? 0, m.round ?? m.speelronde, m.status, m.homeScore ?? m.uitslagThuis ?? null,
    m.awayScore ?? m.uitslagUit ?? null, team(m, true).id, team(m, false).id,
    p ? `${p.year}-${p.month}-${p.day}` : null,
  ])).digest("hex");
}
export function contribution(m: Data): Data | null {
  const r = result(m); if (!r) return null;
  const round = integer(m.round ?? m.speelronde);
  if (round < 1 || round > 34) throw new Error("Invalid round");
  return {home: team(m, true).id, away: team(m, false).id, h: r[0], a: r[1], round, day: deadline(m) ?? 0};
}
export function standings(div: string, contributions: Data, period = 0): Data[] {
  const rows: Data = {};
  for (const t of teams.filter((t) => t.division === div)) {
    rows[t.id] = {
      teamId: t.id, slug: t.id, teamName: t.name, club: t.name, division: div, competitie: `Derde Divisie ${div}`,
      played: 0, wins: 0, draws: 0, losses: 0, goalsFor: 0, goalsAgainst: 0, points: 0, form: [],
      ...(period ? {period} : {}),
    };
  }
  for (const c of (Object.values(contributions) as Data[]).filter(Boolean).sort((a, b)=>(b.day ?? b.round)-(a.day ?? a.round))) {
    if (!c || (period && (c.round <= 12 ? 1 : c.round <= 23 ? 2 : 3) !== period)) continue;
    for (const [id, gf, ga] of [[c.home, c.h, c.a], [c.away, c.a, c.h]]) {
      const row = rows[id]; if (!row) throw new Error(`Unknown standings team ${id}`);
      row.played++; row.goalsFor += gf; row.goalsAgainst += ga;
      if (row.form.length<5)row.form.push(gf>ga?"W":gf===ga?"G":"V");
      if (gf > ga) {
        row.wins++; row.points += 3;
      } else if (gf === ga) {
        row.draws++; row.points++;
      } else row.losses++;
    }
  }
  const sorted = Object.values(rows) as Data[];
  const compare = (a: Data, b: Data) => b.points-a.points || a.played-b.played ||
    (b.goalsFor-b.goalsAgainst)-(a.goalsFor-a.goalsAgainst) || b.goalsFor-a.goalsFor;
  sorted.sort(compare);
  // KNVB 2026/27 section 2.6: tied teams use their mutual results.
  // Period titles explicitly exclude this tie-breaker (section 2.3).
  for (let start=0; start<sorted.length;) {
    let end=start+1; while (end<sorted.length && compare(sorted[start], sorted[end])===0) end++;
    if (end-start>1 && !period) {
      const group=sorted.slice(start, end); const ids=new Set(group.map((r)=>r.teamId));
      const mutual: Data=Object.fromEntries(group.map((r)=>[r.teamId, {points: 0, gf: 0, ga: 0}]));
      for (const c of Object.values(contributions) as Data[]) {
        if (!c || !ids.has(c.home) || !ids.has(c.away)) continue;
        for (const [id, gf, ga] of [[c.home, c.h, c.a], [c.away, c.a, c.h]]) {
          mutual[id].gf+=gf; mutual[id].ga+=ga; mutual[id].points+=gf>ga?3:gf===ga?1:0;
        }
      }
      const tie=(a:Data, b:Data)=>mutual[b.teamId].points-mutual[a.teamId].points ||
        (mutual[b.teamId].gf-mutual[b.teamId].ga)-(mutual[a.teamId].gf-mutual[a.teamId].ga) || mutual[b.teamId].gf-mutual[a.teamId].gf;
      group.sort((a, b)=>tie(a, b) || a.teamName.localeCompare(b.teamName));
      for (const row of group) row.sportingTie=group.some((other)=>other!==row && tie(row, other)===0);
      sorted.splice(start, group.length, ...group);
    } else if (end-start>1) {
      const group=sorted.slice(start, end).sort((a, b)=>a.teamName.localeCompare(b.teamName));
      for (const row of group) row.sportingTie=true;
      sorted.splice(start, group.length, ...group);
    }
    start=end;
  }
  return sorted.map((r, i) => ({...r, position: i+1, positie: i+1, goalDifference: r.goalsFor-r.goalsAgainst,
    gespeeld: r.played, gewonnen: r.wins, gelijk: r.draws, verloren: r.losses,
    doelpuntenVoor: r.goalsFor, doelpuntenTegen: r.goalsAgainst, doelsaldo: r.goalsFor-r.goalsAgainst, punten: r.points}));
}
export function selectLatest(docs: {path: string; data: Data}[], m: Data, poule = false): Map<string, {path: string; data: Data}> {
  const selected = new Map<string, {path: string; data: Data}>();
  for (const doc of docs) {
    const user = uid(doc.data); const group = poule ? `${doc.data.pouleId ?? doc.data.poule ?? ""}__${user}` : user;
    if (!user || !eligible(doc.data, m) || (doc.data.seasonId && doc.data.seasonId !== ACTIVE_SEASON)) continue;
    const previous = selected.get(group);
    const time = millis(doc.data.timestamp) ?? 0; const prev = millis(previous?.data.timestamp) ?? 0;
    if (!previous || time > prev || (time === prev && doc.path < previous.path)) selected.set(group, doc);
  }
  return selected;
}
