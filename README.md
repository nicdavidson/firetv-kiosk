# firetv-kiosk

Turn a Fire TV Stick into a wall display that always comes back to your dashboard. No root needed.

Fire OS does not let you replace the Amazon home screen. The launcher is a protected
package, so `pm disable` fails and there is no "default home app" setting. This repo
works around that with a small watcher that runs on the stick and sends you back to your
kiosk app whenever the Amazon home screen shows up. It still lets you use Spotify,
Plex, Emby and the rest.

## What it does

- **Amazon home screen in front:** bounces to the kiosk within about 2 seconds.
- **Music app playing in front:** bounces after 90 s. The music keeps playing behind the dashboard.
- **Any other app** (video, games): left alone while it plays. Bounces after 3 minutes of silence.
- **After a reboot:** a timer on a Linux box on your LAN pushes the watcher back and starts it.

The watcher decides "something is playing" from `dumpsys audio`. A track in the
`started` state from a non-system uid means real playback. Fire OS keeps one silent track
open as uid 1000 at all times, so that uid is filtered out.

## Will it work on my TV?

| Device | Works? |
|---|---|
| Fire TV Stick / Cube / Fire OS smart TVs (Fire OS 6-8, Android based) | Yes. Tested on a Fire TV Stick 4K Max, Fire OS 7.7.1.7. |
| Fire TV devices on **Vega OS** (e.g. Fire TV Stick 4K Select, 2025) | **No.** Vega has no ADB and no sideloading. Check before you buy. |
| Google TV / Android TV (Chromecast with Google TV, Sony, TCL, Hisense) | Should work, untested. Those launchers are in the default list. Many also let you set a default home app, which is simpler. |
| Roku, Samsung Tizen, LG webOS | No. No ADB, no sideloading. |

## Setup

You need: the TV on your LAN, a kiosk browser on it ([Fully Kiosk Browser](https://www.fully-kiosk.com/) is the default; any app works), and an always-on Linux box with `adb` ([platform-tools](https://developer.android.com/tools/releases/platform-tools)).

1. **Enable ADB on the TV.** Settings > My Fire TV > About: click the device name 7 times. Then Developer options > ADB debugging: On.
2. **Give the TV a fixed IP** (a DHCP reservation in your router).
3. **Connect once and accept the prompt on the TV:**
   ```sh
   adb connect 192.168.1.50:5555
   ```
4. **Install the kiosk browser** (`adb install fully.apk`, or use the Downloader app). Set its start URL to your dashboard, and turn on "Launch on Boot" and "Keep Screen On".
5. **Stop the TV from sleeping:**
   ```sh
   adb shell settings put secure sleep_timeout 0
   ```
6. **Install the keepalive timer** on the Linux box. Edit the path and TV address in `systemd/tv-kiosk.service` first:
   ```sh
   git clone <this repo> ~/firetv-kiosk
   cp ~/firetv-kiosk/systemd/tv-kiosk.* ~/.config/systemd/user/
   systemctl --user daemon-reload
   systemctl --user enable --now tv-kiosk.timer
   loginctl enable-linger "$USER"   # keep user timers running without a login
   ```
   Within a minute the watcher is running on the TV. Press Home on the remote to check: you land back on your dashboard.

To change the kiosk app, the grace times or the music apps, edit the variables at the top of `watcher.sh`. The timer pushes the new copy on the next restart.

To stop it: `adb shell 'pkill -f kiosk_watche[r]'` (it exits within 2 seconds), and disable the timer.

## Optional: block Fire OS updates

An update can reset settings or turn off ADB. Disable the forced updater:

```sh
adb shell pm disable-user com.amazon.tv.forcedotaupdater.v2
```

The main OTA package is protected, so also block these hosts for the TV's IP only, in
your firewall or DNS filter: `softwareupdates.amazon.com`, `updates.amazon.com`,
`amzdigitaldownloads.edgesuite.net`, `amzdigital-a.akamaihd.net`. Remove the block now
and then to take security updates on your own schedule.

## Lessons from putting live cameras on it

If your dashboard shows security cameras, the Fire TV's WebView is the bottleneck:

- **Four WebRTC streams at once crash the WebView.** It segfaults decoding them.
- **One combined "mosaic" stream** (ffmpeg `hstack`/`vstack`) avoids the crash, but the inputs drift. We measured one camera up to 60 s behind.
- **Separate MJPEG streams, one `<img>` per camera, worked.** No video decoder limit, no drift between feeds, timestamps matched the wall clock to the second. We used [go2rtc](https://github.com/AlexxIT/go2rtc) with `ffmpeg:<cam>#video=mjpeg` sources, at about 45% of one Intel N100 core for 4 cameras.
- Add `-probesize 32 -analyzeduration 0` to ffmpeg inputs, or the first stream opened starts several seconds behind.

## Limits

- The Fire boot logo and Amazon's settings screens stay. This is a workaround, not a replacement launcher.
- The watcher runs as the ADB shell user, so it dies on reboot. That is what the keepalive timer is for.
- If ADB debugging gets turned off (by you or an update), the watcher stops coming back.

## License

MIT
