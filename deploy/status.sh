#!/bin/bash
set -u

write_h3_status() {
  local phase="$1" result="$2" message="$3"
  local status_tmp="${H3_STATUS_FILE}.$$"
  mkdir -p "$(dirname "$H3_STATUS_FILE")"
  {
    printf 'H3_PHASE=%q\n' "$phase"
    printf 'H3_RESULT=%q\n' "$result"
    printf 'H3_MESSAGE=%q\n' "$message"
    printf 'H3_UPDATED_AT=%q\n' "$(date -Is)"
  } > "$status_tmp"
  mv "$status_tmp" "$H3_STATUS_FILE"
}
