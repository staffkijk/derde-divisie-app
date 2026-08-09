export interface PredictionReminderPreferences {
  missingPredictionReminders?: boolean;
}

/**
 * Returns whether missing-prediction pushes are enabled for this user.
 * @param {PredictionReminderPreferences|undefined} preferences Stored user
 * notification preferences.
 * @return {boolean} Whether a push may be sent.
 */
export function allowsMissingPredictionReminderPush(
  preferences: PredictionReminderPreferences | undefined
): boolean {
  // Backward-compatible application default: existing users are opted in.
  return preferences?.missingPredictionReminders !== false;
}
