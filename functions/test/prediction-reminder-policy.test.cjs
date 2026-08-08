const test = require("node:test");
const assert = require("node:assert/strict");

const {
  allowsMissingPredictionReminderPush,
} = require("../lib/prediction-reminder-policy.js");

test("explicit false blocks missing prediction push reminders", () => {
  assert.equal(
    allowsMissingPredictionReminderPush({
      missingPredictionReminders: false,
    }),
    false
  );
});

test("legacy users without preferences keep the existing opt-in default", () => {
  assert.equal(allowsMissingPredictionReminderPush(undefined), true);
  assert.equal(allowsMissingPredictionReminderPush({}), true);
});
