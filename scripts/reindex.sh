#!/usr/bin/env bash
# Trigger Khoj to re-index all files in ~/.logmem/files/
KHOJ_PORT=9371
curl -s -X POST "http://localhost:${KHOJ_PORT}/api/update?t=markdown" > /dev/null 2>&1 \
  && echo "Re-index triggered" \
  || echo "Khoj not running on port ${KHOJ_PORT}"
