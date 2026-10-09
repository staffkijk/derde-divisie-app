/** Presentation-only ranking metadata: never derive or initialize points here. */
export function rankingNameForUser(data: Record<string, unknown>): string {
  const name = [data.username, data.usernameLower, data.usernameKey]
    .find((value): value is string => typeof value === "string" && value.trim().length > 0) ?? "Onbekend";
  return name.trim().toLowerCase();
}
