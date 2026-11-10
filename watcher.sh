#!/system/bin/sh
# Runs ON the TV as the adb shell user. Makes a kiosk browser the de facto home screen.
#  - Stock home screen in front: bounce to the kiosk at once.
#  - Music app in front while playing: bounce after MUSIC_GRACE s (playback continues behind).
#  - Any other app: leave it alone while audio/video plays; bounce after IDLE_GRACE s of silence.
# Stop it: adb shell 'pkill -f kiosk_watche[r]'

KIOSK=de.ozerov.fully/.MainActivity   # activity to launch (Fully Kiosk Browser by default)
KIOSK_PKG=${KIOSK%%/*}
# Stock launchers: Fire OS, Android TV, Google TV. Add your vendor's if it differs.
LAUNCHERS='com.amazon.tv.launcher|com.google.android.tvlauncher|com.google.android.apps.tv.launcherx'
MUSIC_APPS='com.spotify.tv.android'   # apps that keep playing in the background
MUSIC_GRACE=90
IDLE_GRACE=180
TICK=2

home() { am start -n "$KIOSK" >/dev/null 2>&1; t=0; }

# A track in "started" state from a non-system uid means something is really playing.
# uid 1000 (system) holds a silent track open all the time, so it is filtered out.
playing() { dumpsys audio | grep ' -- state:started -- ' | grep -qv 'u/pid:1000/'; }

matches() { echo "$1" | grep -qE "$2"; }

t=0
while true; do
  fg=$(dumpsys window | grep -m1 mCurrentFocus)
  if matches "$fg" "$LAUNCHERS"; then
    home
  elif matches "$fg" "$KIOSK_PKG|mCurrentFocus=null"; then
    t=0
  elif playing; then
    if matches "$fg" "$MUSIC_APPS"; then
      t=$((t+TICK)); [ $t -ge $MUSIC_GRACE ] && home
    else
      t=0
    fi
  else
    t=$((t+TICK)); [ $t -ge $IDLE_GRACE ] && home
  fi
  sleep $TICK
done
