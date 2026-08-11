const test = require("node:test");
const assert = require("node:assert/strict");

const {
  allowsMissingPredictionReminderPush,
} = require("../lib/prediction-reminder-policy.js");

test("explicit false blocks missing prediction push reminders", () => {
  assert.equal(
    allowsMissingPredictionReminderPush({missingPredictionReminders: false}, "A"),
    false
  );
});

test("legacy users without preferences keep the existing opt-in default", () => {
  assert.equal(allowsMissingPredictionReminderPush(undefined, "A"), true);
  assert.equal(allowsMissingPredictionReminderPush({}, "B"), true);
});

test("division preferences independently gate reminder pushes", () => {
  const onlyA = {missingPredictionReminders: true, divisionA: true, divisionB: false};
  assert.equal(allowsMissingPredictionReminderPush(onlyA, "A"), true);
  assert.equal(allowsMissingPredictionReminderPush(onlyA, "B"), false);
  assert.equal(allowsMissingPredictionReminderPush(onlyA), false);

  const onlyB = {missingPredictionReminders: true, divisionA: false, divisionB: true};
  assert.equal(allowsMissingPredictionReminderPush(onlyB, "A"), false);
  assert.equal(allowsMissingPredictionReminderPush(onlyB, "B"), true);
});

test("both disabled blocks every reminder push", () => {
  const disabled = {missingPredictionReminders: true, divisionA: false, divisionB: false};
  assert.equal(allowsMissingPredictionReminderPush(disabled, "A"), false);
  assert.equal(allowsMissingPredictionReminderPush(disabled, "B"), false);
});