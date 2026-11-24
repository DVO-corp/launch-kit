#!/bin/bash
# Database dumps: /backups/<db>-<UTC time>.sql.gz
#
#   loop              one dump a day at BACKUP_HOUR_UTC (the "backup" service runs this)
#   now               one dump right now
#   restore <file>    load a dump back (asks nothing — the caller confirms)
#   list              show the dumps
set -euo pipefail

KEEP_DAYS="${BACKUP_KEEP_DAYS:-14}"
HOUR="${BACKUP_HOUR_UTC:-3}"
DIR=/backups

if [ -n "${BACKUP_DATABASE_URL:-}" ]; then
  TARGET=("$BACKUP_DATABASE_URL")
  NAME=external
else
  TARGET=(-h db -U "$POSTGRES_USER" -d "$POSTGRES_DB")
  NAME="$POSTGRES_DB"
fi

dump() {
  local file="$DIR/$NAME-$(date -u +%Y%m%d-%H%M%S).sql.gz"
  # Written under a temporary name: a half-written dump never looks like a good one.
  if pg_dump "${TARGET[@]}" --no-owner --no-privileges | gzip > "$file.tmp"; then
    mv "$file.tmp" "$file"
    find "$DIR" -name '*.sql.gz' -mtime +"$KEEP_DAYS" -delete
    echo "backup ok: $file ($(du -h "$file" | cut -f1))"
  else
    rm -f "$file.tmp"
    echo "backup FAILED" >&2
    return 1
  fi
}

case "${1:-loop}" in
  now)
    dump
    ;;
  list)
    ls -lh "$DIR"/*.sql.gz 2>/dev/null || echo "no dumps yet"
    ;;
  restore)
    file="${2:?usage: restore <file in /backups>}"
    [ -f "$file" ] || file="$DIR/$file"
    gunzip -c "$file" | psql "${TARGET[@]}" -v ON_ERROR_STOP=1 --quiet
    echo "restored from $file"
    ;;
  loop)
    echo "backups every day at ${HOUR}:00 UTC, kept ${KEEP_DAYS} days"
    while :; do
      now=$(date -u +%s)
      next=$(date -u -d "today ${HOUR}:00" +%s)
      [ "$next" -gt "$now" ] || next=$(date -u -d "tomorrow ${HOUR}:00" +%s)
      sleep $((next - now))
      dump || true
    done
    ;;
  *)
    echo "usage: backup.sh loop|now|list|restore <file>" >&2
    exit 2
    ;;
esac
