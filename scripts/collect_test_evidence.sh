#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/docs/test-results"
TIMESTAMP="$(date +"%Y%m%d-%H%M%S")"
FRONTEND_LOG="$RESULTS_DIR/frontend-test-$TIMESTAMP.log"
BACKEND_LOG="$RESULTS_DIR/backend-test-$TIMESTAMP.log"
FRONTEND_JSON="$RESULTS_DIR/frontend-test-$TIMESTAMP.json"
BACKEND_JSON="$RESULTS_DIR/backend-test-$TIMESTAMP.json"
SUMMARY_MD="$RESULTS_DIR/test-summary-$TIMESTAMP.md"

mkdir -p "$RESULTS_DIR"

frontend_status="NOT_RUN"
backend_status="NOT_RUN"

run_frontend() {
  echo "Running frontend tests..."
  if (
    cd "$ROOT_DIR/frontend" &&
    flutter test \
      --reporter expanded \
      --file-reporter "json:$FRONTEND_JSON"
  ) >"$FRONTEND_LOG" 2>&1; then
    frontend_status="PASS"
  else
    frontend_status="FAIL"
  fi
}

run_backend() {
  echo "Running backend tests..."

  if [ ! -f "$ROOT_DIR/backend/package.json" ]; then
    backend_status="SKIPPED"
    printf 'backend package.json not found\n' >"$BACKEND_LOG"
    return
  fi

  if [ -f "$ROOT_DIR/backend/node_modules/jest/bin/jest.js" ]; then
    if (
      cd "$ROOT_DIR/backend" &&
      node node_modules/jest/bin/jest.js \
        --runInBand \
        --json \
        --outputFile "$BACKEND_JSON"
    ) >"$BACKEND_LOG" 2>&1; then
      backend_status="PASS"
      return
    fi
  fi

  if (
    cd "$ROOT_DIR/backend" &&
    npm test -- --runInBand --json --outputFile "$BACKEND_JSON"
  ) >"$BACKEND_LOG" 2>&1; then
    backend_status="PASS"
  else
    backend_status="FAIL"
  fi
}

write_summary() {
  cat >"$SUMMARY_MD" <<EOF
# VitaLink Test Evidence

- Timestamp: \`$TIMESTAMP\`
- Frontend status: **$frontend_status**
- Backend status: **$backend_status**

## Logs

- Frontend log: \`$FRONTEND_LOG\`
- Frontend JSON: \`$FRONTEND_JSON\`
- Backend log: \`$BACKEND_LOG\`
- Backend JSON: \`$BACKEND_JSON\`

## Overall

EOF

  if [ "$frontend_status" = "PASS" ] && [ "$backend_status" = "PASS" ]; then
    cat >>"$SUMMARY_MD" <<EOF
All executed frontend and backend automated tests passed.
EOF
  else
    cat >>"$SUMMARY_MD" <<EOF
At least one test suite did not pass or could not be executed successfully.
Check the logs above for exact details.
EOF
  fi
}

run_frontend
run_backend
write_summary

echo "Frontend status: $frontend_status"
echo "Backend status: $backend_status"
echo "Summary: $SUMMARY_MD"
