#!/bin/sh
# Music widget helper: reads / controls the media player of a phone paired
# with KDE Connect. Playback commands go through the phone's media session
# over Wi-Fi, so the phone does NOT switch its audio output to this PC.
#
#   sh kdeconnect-media.sh poll
#       one line per reachable device that has a player:
#       <device id> TAB <device name, busctl JSON> TAB <mprisremote properties, busctl JSON>
#   sh kdeconnect-media.sh send <device id> <Play|Pause|PlayPause|Next|Previous|Stop>
#   sh kdeconnect-media.sh seek <device id> <position in ms>
#
# Best effort: anything missing simply produces no output. The widget runs
# this with `sh <file>` (no exec bit needed).

export LC_ALL=C
command -v busctl >/dev/null 2>&1 || exit 0

SVC=org.kde.kdeconnect
IFACE=org.kde.kdeconnect.device.mprisremote

# Device ids are only ever [A-Za-z0-9_]; refuse anything else.
valid_id() { case "$1" in ""|*[!A-Za-z0-9_]*) return 1 ;; *) return 0 ;; esac; }

case "$1" in
send)
    valid_id "$2" || exit 0
    case "$3" in Play|Pause|PlayPause|Next|Previous|Stop) ;; *) exit 0 ;; esac
    busctl --user call "$SVC" "/modules/kdeconnect/devices/$2/mprisremote" "$IFACE" sendAction s "$3" >/dev/null 2>&1
    ;;
seek)
    valid_id "$2" || exit 0
    case "$3" in ""|*[!0-9]*) exit 0 ;; esac
    busctl --user set-property "$SVC" "/modules/kdeconnect/devices/$2/mprisremote" "$IFACE" position i "$3" >/dev/null 2>&1
    ;;
*)
    command -v kdeconnect-cli >/dev/null 2>&1 || exit 0
    for id in $(kdeconnect-cli -a --id-only 2>/dev/null); do
        valid_id "$id" || continue
        base="/modules/kdeconnect/devices/$id"
        props=$(busctl --user --json=short call "$SVC" "$base/mprisremote" \
                org.freedesktop.DBus.Properties GetAll s "$IFACE" 2>/dev/null) || continue
        [ -z "$props" ] && continue
        name=$(busctl --user --json=short get-property "$SVC" "$base" org.kde.kdeconnect.device name 2>/dev/null)
        [ -z "$name" ] && name='{}'
        printf '%s\t%s\t%s\n' "$id" "$name" "$props"
    done
    ;;
esac
exit 0
