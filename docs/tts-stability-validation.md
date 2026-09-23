# TTS stability and settings validation

The repair branch incorporates upstream `7f89bc86` (1.9.87+512). Upstream's
vendored Quinn now returns non-`WouldBlock` UDP receive errors instead of
retrying indefinitely. That removes a specific CPU spin risk; it does not
establish the cause of any particular device's heat report.

## Automated checks

- `.github/workflows/check_flutter.yml` generates app/plugin code, checks Dart
  formatting, runs the analyzer and all Flutter tests, and uploads widget
  screenshots. Formatting patches are downloadable for machines without Dart.
- The existing iOS, macOS and Windows workflows build the PR without merging it.
  The iOS artifact is unsigned and is not a TestFlight release.
- `python3 tool/check_thread_stats.py` compiles the production Darwin sampler
  with only Flutter registration glue omitted. It samples 1,000 times and
  asserts that the calling thread's Mach send-right references do not increase.
  This needs existing macOS/Xcode tools, not Flutter. A before/after run during
  this repair measured references `2 → 1002` before and `2 → 2` after.

Code-level resource limits and fake-player tests do not prove AVPlayer behavior,
jetsam prevention, battery usage, or device temperature under real playback.

## iPhone 15 Pro acceptance run

Use the same book, TTS endpoint, network, brightness and ambient temperature to
compare the baseline and candidate release builds. Record iOS version, build
SHA, start/end battery level, RSS/CPU samples and any crash or jetsam logs.
Do not keep the performance overlay enabled for battery comparisons; diagnostics
itself adds foreground sampling work.

1. Listen for at least two hours, including multiple pages and series chapters.
   Alternate ten minutes with the screen on and ten minutes locked. Check audio
   continuity, chapter navigation, lock-screen subtitle and play/pause actions.
2. Pause for five minutes while locked. There should be no synthesis requests
   or silently looping keepalive audio. Resume from Control Center, then stop.
3. During synthesis, rapidly pause/resume, skip, change chapter and switch a
   saved voice at the same endpoint. Only the latest requested session/voice
   should play; a stopped session must not restart.
4. Test a dropped network, a stalled response, invalid credentials and an
   interrupted audio route (call, headphones disconnected). Failure should be
   recoverable, and abandoned synthesis must not keep the app busy indefinitely.
5. Leave the reader for the bookshelf while listening through a series boundary,
   then reopen the currently playing chapter. Playback should continue without
   retaining the previous reader route or opening it unexpectedly.
6. Test settings at 320 px width, landscape, large text and dark mode: service
   selection, voice presets, preview, validation, advanced templates and the
   pronunciation editor. Existing JSON configurations must retain their values.

Pass criteria: no crash/OS termination, bounded live audio sources and memory
after warm-up, no continued work after pause/stop, correct voice and progress,
and no sustained unexplained CPU load. Temperature and battery observations
must be reported as device measurements, separately from CI results.
