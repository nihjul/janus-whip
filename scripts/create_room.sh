#!/usr/bin/env bash

set -euo pipefail

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 1
fi

if [[ -z "${JANUS_URL:-}" ]]; then
  echo "ERROR: JANUS_URL is not set" >&2
  exit 1
fi

BASE_URL="http://${JANUS_URL}:8088/janus/"

ROOM_ID="${JANUS_ROOM_ID:-1212}"
ROOM_SECRET="${JANUS_ROOM_SECRET:-tv2}"
ROOM_PRIVATE="${JANUS_ROOM_PRIVATE:-true}"
ROOM_PUBLISHERS="${JANUS_ROOM_PUBLISHERS:-1}"
ROOM_AUDIOCODEC="${JANUS_ROOM_AUDIOCODEC:-opus}"
ROOM_VIDEOCODEC="${JANUS_ROOM_VIDEOCODEC:-h264}"
ROOM_BITRATE="${JANUS_ROOM_BITRATE:-0}"

generate_transaction() {
  LC_ALL=C tr -dc 'a-zA-Z1-9' </dev/urandom | dd bs=11 count=1 status=none
}

janus_post() {
  local url="$1"
  local payload="$2"
  local response janus reason

  response="$(curl -fsS -X POST "$url" -H "Content-Type: application/json" -d "$payload")"
  janus="$(jq -r '.janus // empty' <<<"$response")"

  case "$janus" in
    success|event|ack)
      printf '%s\n' "$response"
      ;;
    error)
      reason="$(jq -r '.error.reason // "unknown error"' <<<"$response")"
      echo "ERROR: $reason" >&2
      exit 1
      ;;
    *)
      echo "ERROR: unexpected Janus response: $response" >&2
      exit 1
      ;;
  esac
}

session_payload="$(jq -cn --arg tx "$(generate_transaction)" '{janus:"create", transaction:$tx}')"
session_response="$(janus_post "$BASE_URL" "$session_payload")"
session_id="$(jq -r '.data.id // empty' <<<"$session_response")"

if [[ -z "$session_id" ]]; then
  echo "ERROR: could not parse session id" >&2
  exit 1
fi

attach_payload="$(jq -cn --arg tx "$(generate_transaction)" '{janus:"attach", plugin:"janus.plugin.videoroom", transaction:$tx}')"
attach_response="$(janus_post "${BASE_URL}${session_id}" "$attach_payload")"
handler_id="$(jq -r '.data.id // empty' <<<"$attach_response")"

if [[ -z "$handler_id" ]]; then
  echo "ERROR: could not parse handler id" >&2
  exit 1
fi

create_payload="$({
  jq -cn \
    --arg tx "$(generate_transaction)" \
    --argjson room "$ROOM_ID" \
    --arg secret "$ROOM_SECRET" \
    --argjson is_private "$ROOM_PRIVATE" \
    --argjson publishers "$ROOM_PUBLISHERS" \
    --arg audiocodec "$ROOM_AUDIOCODEC" \
    --arg videocodec "$ROOM_VIDEOCODEC" \
    --argjson bitrate "$ROOM_BITRATE" \
    '{
      janus:"message",
      transaction:$tx,
      body:{
        request:"create",
        room:$room,
        permanent:false,
        secret:$secret,
        is_private:$is_private,
        publishers:$publishers,
        audiocodec:$audiocodec,
        videocodec:$videocodec,
        bitrate:$bitrate
      }
    }'
})"

create_response="$(janus_post "${BASE_URL}${session_id}/${handler_id}" "$create_payload")"
room="$(jq -r '.plugindata.data.room // empty' <<<"$create_response")"

if [[ -z "$room" ]]; then
  echo "ERROR: could not parse created room id" >&2
  exit 1
fi

printf '%s\n' "$room"
