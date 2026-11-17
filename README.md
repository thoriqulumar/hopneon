# Neon Hop

Neon Hop is a one-tap endless runner built for Godot 4.x. Base gameplay works offline using engine primitives and system fonts. Optional Android AdMob integration is disabled by default and requires manual plugin/privacy setup.

## Gameplay

Tap the screen (or click/press Space on desktop) to hop over neon obstacles. Speed increases with survival distance and is capped at 560 pixels/second. One point represents 32 world pixels. Jump input is buffered briefly, and coyote time makes late edge jumps responsive.

Pause with the on-screen pause button or Escape. Retry resets the active run in place without reloading the application or returning to the menu.

## Structure

```text
project.godot                     Project, portrait display, renderer, and input
scenes/main.tscn                  Application entry point
scenes/gameplay/game.tscn         Game world, HUD, floor, and spawner
scenes/components/                Reusable player and obstacle scenes
scenes/ui/                        Main menu and game-over overlay
scripts/autoload/game_state.gd    Local best-score persistence
scripts/gameplay/game.gd          Run state, spawning, scoring, and difficulty
scripts/gameplay/run_state.gd     Deterministic speed, distance, and phase model
scripts/autoload/progress_store.gd Versioned JSON, validation, backup, migration
scripts/autoload/feedback.gd      Procedural PCM sounds, SFX bus, button wiring, haptics
scripts/autoload/ad_manager.gd    Optional Android ads policy and run-bound rewards
scripts/ads/                     Desktop-safe interface and pinned Poing native adapter
config/ads.cfg                   Disabled-by-default ads and production placeholders
scripts/ui/feedback_settings.gd   Volume, mute, haptic, and shake controls
scripts/components/               Drawing, player, obstacle, and safe-area code
scripts/ui/                       Menu, HUD, pause, and game-over behavior
tests/                            Headless scene and state-transition checks
```

## Run

1. Use Godot 4.7.2 for the current project's tested configuration, with exactly matching export templates.
2. Import this folder, or run `godot --editor --path .` here.
3. Press **F5** to run.
4. Desktop: left-click, Space, or Enter. Android: tap anywhere in gameplay.

The logical viewport is 540×960 (9:16). `canvas_items` stretch with `expand` supports varied phone ratios, and UI roots apply display safe-area insets at runtime.

## Android export

See [ANDROID_RELEASE.md](ANDROID_RELEASE.md) for the prepared debug APK/release AAB presets, icons, SDK/JDK setup, signing, and the manual release checklist. No Android build is claimed. The game needs no Internet permission or backend.

The Compatibility renderer, primitive drawing, simple collision shapes, and low node count are chosen for a 60 FPS target on mid-range Android hardware.

The art direction is fully procedural: a lightweight canvas shader provides the dark layered gradient, `_draw()` renders the parallax grid and skyline, and a capped 64-particle pool handles jump dust and collision bursts. Player squash-and-stretch transforms only its visual child, preserving stable collision geometry.

## Automated checks

With a Godot executable on the path, run:

```text
godot --headless --path . --script res://tests/menu_transition_test.gd
godot --headless --path . --script res://tests/core_gameplay_test.gd
godot --headless --path . --script res://tests/progression_test.gd
godot --headless --path . --script res://tests/progression_test.gd -- --restart-read
godot --headless --path . --script res://tests/feedback_test.gd
godot --headless --path . --script res://tests/feedback_test.gd -- --restart-read
godot --headless --path . --script res://tests/ads_test.gd
```

Spawning uses a fixed seed and distance-based spacing. Obstacle height stays below the jump arc, and the minimum gap at maximum speed remains longer than a complete jump so consecutive obstacles remain achievable.

## Progress and local saves

The HUD displays current score and personal best. Open **PROGRESS & COSMETICS** from the main menu for today's and lifetime runs, distance, active play time, best score, milestone count, color selection, and reset. Reset opens a confirmation dialog; Cancel leaves progress intact. Confirming replaces both the save and backup with defaults.

Milestones are awarded once at 100, 250, 500, and 1,000 points. Reach 100 points to unlock Violet. Travel 32,000 world pixels (1,000 distance points) over any number of runs to unlock Gold. Cosmetics are optional, persist when equipped, and have no effect on physics or difficulty.

Each cosmetic tier adds visible effects: Cyan has a clean core glow; Violet adds two rotating energy arcs and orbiting lights; Gold keeps the orbit, adds a slow solar corona, sparkling ribbons, and a larger gold jump burst. Collection cards and the equipped showcase use the same animated visual script as gameplay, including previews of locked tiers. Effects pause with gameplay and use bounded procedural geometry and the existing particle cap.

Progress and feedback preferences are stored as validated version 3 JSON at `user://neon_hop_progress.json`, with a `.bak` recovery file. Godot resolves `user://` to the platform's application data directory on desktop and the app's private storage on Android. Saving requires no extra permissions, accounts, network services, or database. Use **Project > Open User Data Folder** in Godot to inspect desktop saves.

Saves occur on run start/end, every five active seconds, pause/background, cosmetic selection, and normal exit. A sudden process kill can lose at most the activity since the last successful checkpoint. Active runs restart from the beginning after relaunch; accumulated progress is retained. Pause and menu time do not count as play time.

Daily history uses the device's local calendar date, requires no internet clock, and retains prior days. A run crossing midnight adds subsequent time/distance to the new date; its run count belongs to the date it started. Changing the device clock changes daily attribution.

Writes are flushed to a temporary file, checked, then renamed into place. Only valid data rotates into the backup. Missing saves use defaults; corrupted primary saves fall back to the backup; malformed fields are sanitized. Version 1/2 JSON and the original `neon_hop.cfg` best score migrate automatically. Saves from a newer schema are preserved read-only with an explanatory message in Progress. Failed writes leave progress in memory and show a storage message there.

The tests use separate `user://neon_hop_test_*.json` files so they cannot reset a player's profile. They cover save/reload, corrupt recovery, outdated/newer schemas, daily rollover, unlocks, confirmation/cancel, and gameplay integration. Physical Android verification is still needed for background/resume, force-stop/relaunch, and storage-full behavior. Uninstalling the app normally removes its private local data.

## Audio and feedback

Open **SOUND & FEEDBACK** from the menu or pause screen. The SFX slider controls a dedicated audio bus; Mute immediately silences and stops effects while remembering your volume. Haptics and collision shake have independent switches. These preferences survive restarts and progression resets. Slider changes apply immediately and are saved after a 350 ms debounce or when closing/backgrounding the app.

All four sounds are original procedural audio generated by `feedback.gd` once at startup: a rising sine chirp for jumping (120 ms), a low descending tone with seeded noise for collisions (220 ms), a three-note chime for newly earned score milestones (300 ms), and a soft button tick (45 ms). They use mono 16-bit PCM at 24 kHz, short attack/release envelopes, four bounded voices, cooldowns, and conservative gains. Total waveform data is under 34 KB; no audio assets, downloads, attribution, or third-party licenses are required. Button sounds fire on activation, not hover or every slider movement. There is no background music or per-point score ticking.

Collision shake moves only the world camera by at most four logical pixels for 180 ms; the HUD remains stationary. Retry resets the offset immediately. No flashes are added. Android jump/collision pulses last 12/35 ms and are independent of sound mute. Other platforms skip haptic calls; phones without a vibrator safely ignore them.

The Android export preset enables `permissions/vibrate=true`, as required by [Godot's handheld vibration API](https://docs.godotengine.org/en/4.5/classes/class_input.html#class-input-method-vibrate-handheld). No runtime permission dialog or plugin is used. Check tactile strength, sound latency, speaker/headphone levels, silent-mode behavior, and background/resume on a physical Android device before release.

## Optional Android monetization

See [ADMOB_INTEGRATION.md](ADMOB_INTEGRATION.md) for the chosen Poing v5.1.0 plugin, exact manual installation, consent and regional privacy gates, public test IDs, and production checklist. The addon is not installed or enabled by this repository. Desktop and offline play remain available without it.

Once configured, game over may offer one optional rewarded continue. Only an SDK-confirmed reward followed by dismissal resumes the same run; score and statistics are preserved. Capped interstitials are considered only when leaving game over, never during play. Missing ads skip immediately. The local ad tests use a fake provider and generate no ad requests/impressions; a real Android test-ads build still needs manual validation.

## Device verification checklist

- Test tap response, jump tuning, and collisions on a physical Android device.
- Check UI insets on a notched device and on 16:9, 19.5:9, and 20:9 screens.
- Confirm behavior after backgrounding and resuming the app.
- Verify the local best score survives an app restart.
- Profile on the oldest target device before release.
