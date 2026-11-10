#!/bin/bash
# Runs on an always-on Linux box on the same LAN. The watcher dies when the TV reboots;
# this pushes it back and starts it. Run it every minute (see systemd/).
# Usage: keepalive.sh <tv-ip>[:5555]
set -u
TV=${1:?usage: keepalive.sh <tv-ip>[:port]}
[[ $TV == *:* ]] || TV="$TV:5555"
ADB=${ADB:-adb}
HERE=$(cd "$(dirname "$0")" && pwd)

"$ADB" connect "$TV" >/dev/null 2>&1
"$ADB" -s "$TV" shell pgrep -f 'kiosk_watche[r]' >/dev/null 2>&1 && exit 0
"$ADB" -s "$TV" push "$HERE/watcher.sh" /data/local/tmp/kiosk_watcher.sh >/dev/null 2>&1 || exit 0
"$ADB" -s "$TV" shell 'chmod 755 /data/local/tmp/kiosk_watcher.sh; nohup /data/local/tmp/kiosk_watcher.sh >/dev/null 2>&1 &'
