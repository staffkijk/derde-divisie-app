export interface PredictionReminderPreferences {
  missingPredictionReminders?: boolean;
  divisionA?: boolean;
  divisionB?: boolean;
}

/**
 * Returns whether missing-prediction pushes are enabled for this user.
 * Missing fields preserve the application opt-in default for existing users.
 */
export function allowsMissingPredictionReminderPush(
  preferences: PredictionReminderPreferences | undefined,
  division?: unknown
): boolean {
  if (preferences?.missingPredictionReminders === false) return false;
  const normalized = String(division || "").trim().toUpperCase();
  if (normalized === "A") return preferences?.divisionA !== false;
  if (normalized === "B") return preferences?.divisionB !== false;
  return preferences?.divisionA !== false && preferences?.divisionB !== false;
}