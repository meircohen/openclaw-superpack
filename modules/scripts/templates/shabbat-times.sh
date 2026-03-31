#!/usr/bin/env bash
# Shabbat time checker — suppresses non-critical alerts during Shabbos
# Configure your location coordinates below

LAT="${SHABBAT_LAT:-40.7128}"   # Default: New York City
LON="${SHABBAT_LON:--74.0060}"
TZ="${SHABBAT_TZ:-America/New_York}"

case "${1:-check}" in
  check)
    DOW=$(date +%u)
    HOUR=$(date +%H)
    # Simple Friday sunset check (refine with hebcal API for accuracy)
    if [ "$DOW" = "5" ] && [ "$HOUR" -ge 18 ]; then echo "shabbat"; exit 0; fi
    if [ "$DOW" = "6" ]; then
      if [ "$HOUR" -lt 20 ]; then echo "shabbat"; exit 0; fi
    fi
    echo "weekday"
    ;;
  *)
    echo "Usage: shabbat-times.sh check"
    ;;
esac
