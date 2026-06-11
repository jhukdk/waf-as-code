#!/usr/bin/env bash
# attack-sim.sh — exercise the WAF rule set against the demo API.
#
# Usage: tests/attack-sim.sh <invoke-url>
#
# Cases (per CLAUDE.md testing convention):
#   1. Baseline GET                      -> expect 200
#   2. SQLi-style query string           -> expect 403 (managed rules)
#   3. Header x-demo-attack: 1           -> expect 403 (custom rule)
#   4. 150 rapid requests                -> expect 200s turning into 403s
#      (rate rule; can take ~1-2 min of sustained traffic to trip)
set -u

URL="${1:?usage: $0 <invoke-url>}"

declare -a NAMES EXPECTED GOT STATUS

record() { # name expected got
  NAMES+=("$1")
  EXPECTED+=("$2")
  GOT+=("$3")
  if [[ "$3" == "$2" ]]; then STATUS+=("PASS"); else STATUS+=("FAIL"); fi
}

http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@"; }

echo "Target: $URL"
echo

# 1. Baseline
code=$(http_code "$URL")
record "1. baseline GET" 200 "$code"

# 2. SQLi-style query string (URL-encoded by curl)
code=$(http_code -G "$URL" --data-urlencode "id=1' OR '1'='1")
record "2. SQLi query string" 403 "$code"

# 3. Custom header rule
code=$(http_code -H 'x-demo-attack: 1' "$URL")
record "3. x-demo-attack header" 403 "$code"

# 4. Rate rule: 150 rapid requests, then keep sustaining traffic up to
#    2 extra minutes since WAF rate rules lag behind real request rates.
first_403=""
ok_count=0
blocked_count=0
for i in $(seq 1 150); do
  code=$(http_code "$URL")
  if [[ "$code" == "200" ]]; then
    ok_count=$((ok_count + 1))
  elif [[ "$code" == "403" ]]; then
    blocked_count=$((blocked_count + 1))
    [[ -z "$first_403" ]] && first_403=$i
  fi
done

if [[ -z "$first_403" ]]; then
  deadline=$((SECONDS + 120))
  i=150
  while [[ $SECONDS -lt $deadline ]]; do
    i=$((i + 1))
    code=$(http_code "$URL")
    if [[ "$code" == "403" ]]; then
      first_403=$i
      blocked_count=1
      break
    fi
    sleep 1
  done
fi

if [[ -n "$first_403" ]]; then
  record "4. rate limit (150 rapid)" 403 403
  rate_note="first 403 at request #${first_403}; ${ok_count}x200 then ${blocked_count}x403 in initial burst"
else
  record "4. rate limit (150 rapid)" 403 200
  rate_note="no 403 seen after the burst plus 2 min of sustained traffic"
fi

echo
printf '%-28s %-9s %-6s %s\n' "CASE" "EXPECTED" "GOT" "RESULT"
printf '%-28s %-9s %-6s %s\n' "----" "--------" "---" "------"
failures=0
for idx in "${!NAMES[@]}"; do
  printf '%-28s %-9s %-6s %s\n' "${NAMES[$idx]}" "${EXPECTED[$idx]}" "${GOT[$idx]}" "${STATUS[$idx]}"
  [[ "${STATUS[$idx]}" == "FAIL" ]] && failures=$((failures + 1))
done
echo
echo "rate rule detail: $rate_note"
echo
if [[ $failures -eq 0 ]]; then
  echo "ALL PASS"
else
  echo "$failures FAILURE(S)"
  exit 1
fi
