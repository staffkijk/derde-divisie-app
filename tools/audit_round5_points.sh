#!/usr/bin/env bash
set -euo pipefail

export TZ=Europe/Amsterdam
node tools/audit_repair_prediction_points.cjs --round=5 "$@"
