
#!/usr/bin/env bash

# Controlled load test for the three-tier Docker POC
# Frontend: Nginx on port 8080
# Backend: Node.js API on port 3200
# Database: MySQL accessed through the backend API

set -euo pipefail

# Load-test configuration
DURATION="${DURATION:-60}"
WORKERS="${WORKERS:-5}"

FRONTEND_URL="http://127.0.0.1:8080"
BACKEND_URL="http://127.0.0.1:3200"

# Validate configuration
if ! [[ "$DURATION" =~ ^[1-9][0-9]*$ &&
        "$WORKERS" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: DURATION and WORKERS must be positive integers."
  exit 1
fi

# Keep the test controlled to avoid overwhelming the host
if (( DURATION > 300 || WORKERS > 20 )); then
  echo "ERROR: Maximum duration is 300 seconds and maximum workers is 20."
  exit 1
fi

# Verify all three containers are running
for service in frontend backend mysql; do
  if [[ "$(docker compose ps --status running -q "$service")" == "" ]]; then
    echo "ERROR: $service is not running."
    exit 1
  fi
done

# Verify both HTTP endpoints are reachable
curl -fsS -o /dev/null "$FRONTEND_URL/"
curl -fsS -o /dev/null "$BACKEND_URL/api/books"

echo "===================================="
echo " Three-Tier Docker Load Test"
echo "===================================="
echo "Duration: ${DURATION}s"
echo "Workers:  $WORKERS"
echo "Frontend: $FRONTEND_URL"
echo "Backend:  $BACKEND_URL"
echo "===================================="

# Create a temporary directory for test results
RESULT_DIR="$(mktemp -d)"
PIDS=()

# Clean up background processes and temporary files
cleanup() {
  trap - EXIT INT TERM

  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done

  wait 2>/dev/null || true
  rm -rf "$RESULT_DIR"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Each worker repeatedly requests frontend and API resources
worker() {
  local worker_id="$1"
  local deadline="$2"
  local success=0
  local failed=0
  local status

  while (( SECONDS < deadline )); do

    # Nginx: request the React frontend
    # Node.js + MySQL: request book and author data
    for url in \
      "$FRONTEND_URL/" \
      "$BACKEND_URL/api/books" \
      "$BACKEND_URL/api/authors"; do

      status="$(curl -s -o /dev/null \
        -w '%{http_code}' \
        --connect-timeout 2 \
        --max-time 5 \
        "$url")" || status="000"

      if [[ "$status" == "200" ]]; then
        ((success+=1))
      else
        ((failed+=1))
      fi
    done

    # Small delay to prevent an uncontrolled request flood
    sleep 0.1
  done

  printf '%s %s\n' "$success" "$failed" \
    > "$RESULT_DIR/worker-${worker_id}.txt"
}

# Launch concurrent workers
DEADLINE=$((SECONDS + DURATION))

for ((i=1; i<=WORKERS; i++)); do
  worker "$i" "$DEADLINE" &
  PIDS+=("$!")
done

# Wait for all workers to finish
for pid in "${PIDS[@]}"; do
  wait "$pid"
done

# Aggregate request results
awk '
  { success += $1; failed += $2 }
  END {
    total = success + failed
    printf "\n========== RESULTS ==========\n"
    printf "Successful requests: %d\n", success
    printf "Failed requests:     %d\n", failed
    printf "Total requests:      %d\n", total
    if (total > 0)
      printf "Success rate:        %.2f%%\n", 100 * success / total
    printf "=============================\n"
  }
' "$RESULT_DIR"/worker-*.txt

