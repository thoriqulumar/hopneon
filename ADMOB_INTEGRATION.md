# Neon Hop — optional Android AdMob integration

## Status and chosen plugin

Inspected on 2026-10-22: the installed editor reports **4.7.2.stable.steam.ed1daf0bf**, and this project declares Godot 4.7. The integration targets **Poing Studios Godot AdMob Plugin v5.1.0**, a maintained stable release with Android binaries/templates for Godot 4.7.2. [Pinned release and assets](https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0).

The other maintained candidate inspected was [godot-sdk-integrations/godot-admob v7.0](https://github.com/godot-sdk-integrations/godot-admob/releases), whose release targets Godot 4.7. Poing was selected for its stable tagged GDScript API, rewarded/fullscreen callback objects, and UMP/privacy-options support. Do not mix these plugins or install the older Godot 3 AdMob plugin.

**What is implemented:** desktop-safe abstraction, native adapter, consent gate, loading/backoff, rewarded continue, game-over interstitial policy, privacy entry point, and network-free policy/gameplay tests.

**What is not done:** the third-party addon/native Android libraries are not installed, ads are not enabled, no AdMob account/messages were configured, no Android ads build was run, and no native consent form or Google test ad was displayed. No live requests, clicks, impressions, or credentials were generated. Source/API inspection and local fake-provider tests do not establish device compatibility.

## Files and runtime behavior

- `config/ads.cfg`: public feature switches, audience/release gates, and production identifier placeholders. Disabled by default; debug builds always force Google's test unit IDs.
- `scripts/autoload/ad_manager.gd`: availability, consent/context checks, cooldowns, stale-callback tokens, and run-bound reward policy. No native plugin classes are referenced statically.
- `scripts/ads/ad_provider.gd`: project-owned interface; its methods are not claims about any SDK API.
- `scripts/ads/poing_provider.gd`: the sole native adapter, dynamically loading the exact v5.1.0 scripts only after Android/native-singleton/version checks.
- `scripts/gameplay/game.gd`, `scripts/ui/game_over.gd`: game-over offer, final-break actions, and safe resume of the same run.
- `tests/ads_test.gd`, `fake_ad_provider.gd`, `ad_manager_fixture.gd`: local callbacks only, with no SDK/network/impressions.

Ads cannot appear on launch, pause, return from background, or active gameplay. Loading callbacks only update availability; they never present an ad. If an ad is not ready when a break is requested, Retry/Menu continues immediately with no queued popup. Game-over buttons are disabled while a native full-screen ad is outstanding.

After SDK initialization, the existing Sound & Feedback volume/mute preferences are forwarded through the documented `MobileAds.set_app_volume` / `set_app_muted` methods. Game sound effects stop when requesting a full-screen ad.

Rewarded continue is an explicit **WATCH AD · EXTRA LIFE** choice. It is hidden when unavailable. There is at most one attempt and one extra life per run, with a 30-second interval after any full-screen ad. Closing/skipping/failing the ad grants nothing. Only a positive `RewardedItem.amount` in `OnUserEarnedRewardListener.on_user_earned_reward` confirms eligibility; the game resumes after dismissal. Tokens reject duplicate/stale rewards. A confirmed continue clears nearby obstacles, provides new spawn distance, and preserves score, difficulty, daily statistics, and run count.

Interstitials are considered only when **Retry or Main Menu is chosen after game over**. They require three completed runs since the previous interstitial, at least 120 seconds since launch and the last full-screen ad, and a ready ad. Maximum three interstitial attempts per session; a rewarded ad also starts the interstitial cooldown. Skipped opportunities are not accumulated for later presentation. Caps are conservative session-memory limits; restarting starts a new two-minute grace period.

Load failures use 30/60/120/240/300-second backoff, with 30-second load timeouts and 55-minute cache expiry. SDK initialization is attempted once per session after the consent gate, with a 35-second initialization timeout. Consent update failures/timeouts leave ads off while ordinary play remains available. Native presentation remains blocked until dismissal/failure callbacks; a timer never invents a reward or resumes gameplay over an outstanding ad.

## Manual plugin installation for test ads

1. Keep `config/ads.cfg` disabled while installing. Use the exact [v5.1.0 release](https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0), not a nightly build.
2. Download **`poing-godot-admob-v5.1.0.zip`** and import its `addons/admob/` into this project. Preserve the bundled MIT license notices. Enable AdMob in **Project → Project Settings → Plugins**, then let Godot import/register its GDScript classes.
3. In **Project → Tools → AdMob Manager → Android → Download & Install**, install the Android libraries matching v5.1.0/Godot 4.7.2. If the automatic download fails, use **`android-template-v4.7.2.zip` from the same release** and the vendor's manual installation instructions. Confirm `addons/admob/android/bin/package.gd` and the ads library are installed. See [Poing's installation guide](https://poingstudios.github.io/godot-admob-plugin/5.0/).
4. Install the Android Gradle build template as described in `ANDROID_RELEASE.md`. For an ads-enabled debug APK, enable **Use Gradle Build** on **Android Debug APK** too. Poing v5.1.0 does not support its native SDK through prebuilt APK export. Keep the matching JDK, SDK, template, and target API setup; resolve Gradle dependency errors before testing.
5. In Project Settings, set **`admob/general/android/enabled=true`** and use the public Android sample App ID below. Leave iOS and all mediation networks disabled. The existing `false` setting deliberately prevents accidental native packaging before setup.
6. For each ads-enabled Android export preset, enable **Internet** and **Access Network State**, retaining **Vibrate** for haptics. The checked-in offline presets leave network permissions disabled. Inspect the final merged manifest: Google dependencies may add permissions such as advertising ID. Review/remove optional permissions only in accordance with the chosen SDK's documented configuration and intended audience. Do not add location, microphone, camera, or storage access.
7. Complete the privacy/audience setup below before turning on the game feature. `config/*.cfg` and `addons/admob/plugin.cfg` are explicitly included in export filters. Do not remove them; the runtime uses these files for feature and version checks.
8. For test-only device builds, use this configuration only after the review/message gates are actually complete:

```ini
[ads]
enabled=true
test_ads=true
production_ready=false
audience_reviewed=true
consent_messages_configured=true
audience="general_audience"
android_app_id="REPLACE_WITH_PRODUCTION_ADMOB_APP_ID"
rewarded_unit_id="REPLACE_WITH_PRODUCTION_REWARDED_UNIT_ID"
interstitial_unit_id="REPLACE_WITH_PRODUCTION_INTERSTITIAL_UNIT_ID"
```

The runtime deliberately ignores production placeholders in test mode. App registration/UMP messaging is configured separately in AdMob; if the public sample App ID cannot return your configured privacy messages, consent will fail closed. For regional UMP validation, use your registered App ID with published test messages, a registered test device, and the vendor/Google consent-debug instructions. Keep `test_ads=true`, so ad units remain Google's dedicated samples throughout those tests. Do not force a fake geography on ordinary devices.

### Public Google development IDs

| Purpose | ID |
| --- | --- |
| Android sample App ID (Project Settings) | `ca-app-pub-3940256099942544~3347511713` |
| Rewarded unit (selected by AdManager) | `ca-app-pub-3940256099942544/5224354917` |
| Interstitial unit (selected by AdManager) | `ca-app-pub-3940256099942544/1033173712` |

An App ID uses `~`; ad unit IDs use `/`. These are Google's public samples, not production identifiers or secrets. [Google's Android test-ad guide](https://developers.google.com/admob/android/test-ads). Never click live ads for testing, automate ad watching, or simulate production impressions. The local fake tests never contact Google.

## Privacy and consent launch gate

The implemented policy supports an explicitly reviewed **general audience**. `audience="unconfigured"` blocks ads; declaring child/mixed/under-age users is not implemented by this configuration. Do not switch to general audience merely to enable ads. Before any child/mixed-audience release, add an appropriate age flow, per-user treatment, Families/COPPA/under-age handling, and re-audit SDKs and rewards. Current max ad content rating is G, but that alone is not a children-compliance implementation. [Google targeting guidance](https://developers.google.com/admob/android/targeting).

At every app session, UMP consent information is updated from the menu. Ads are not initialized or loaded before a successful permission check. Required forms wait for the menu if gameplay has already started. While a form is visible, starting a new game is blocked. Failure or unknown status keeps ads unavailable. We do not store or trust a separate local "consent granted" boolean.

The pinned plugin does not expose `can_request_ads()`: the adapter uses its documented `ConsentInformation.get_consent_status()` values `NOT_REQUIRED=1` or `OBTAINED=3` after the successful update/form callback. `OBTAINED` means choices were collected, not that every personalization purpose was accepted. Requests additionally set the supported Google extras `npa="1"` and disable publisher first-party ID. The native v5.1.0 converter passes extras to `setGoogleExtrasBundle`. Non-personalized ads still have storage/privacy obligations; SDK/UMP purpose and vendor signals must be validated on the device. No personalized-ad mode is enabled by this project.

Required manual regional work before setting `consent_messages_configured=true`:

- **EEA, UK, Switzerland:** publish the appropriate UMP European regulations message for the registered application, including the actual publisher/privacy policy, vendor/purpose choices, and consent revocation. Test acceptance, rejection, and updated messages. [Google UMP setup](https://developers.google.com/admob/android/next-gen/privacy).
- **Applicable US states:** configure US-state privacy messages and the required opt-out/sale/sharing choices in AdMob. UMP/Google SDK manage applicable GPP signals; do not replace them with a project boolean or assume NPA is sufficient. Verify opt-out behavior and SDK handling using the [US-state privacy guidance](https://developers.google.com/admob/android/privacy/us-states).
- **Other supported regions:** review local consent/notice/age obligations and configure regional messaging before shipping there. Use the UMP result rather than a hardcoded country list. If coverage is uncertain, leave monetization off in that release.
- Publish a real privacy-policy URL and update Play Data Safety/contains-ads and other store declarations for the actual Google SDK data collection. The old game-only "offline/local data" description no longer covers an ads-enabled build.

When the SDK reports privacy options required, the menu exposes **PRIVACY OPTIONS**, calling the verified `UserMessagingPlatform.show_privacy_options_form`. Before presenting, cached ads are discarded and the permission gate closes. After dismissal it is rechecked before reloading. If an update fails, **PRIVACY · RETRY CHECK** remains available. This flow changes SDK privacy choices, not gameplay progress; resetting scores never resets consent.

## Exact production enablement checklist

- [ ] Install and pin the v5.1.0 addon and matching native Android files. Record their versions/checksums. Re-review this adapter before any plugin upgrade; other versions are intentionally rejected.
- [ ] Verify the target audience, supported regions, age policy, and privacy/data disclosures. Publish and device-test UMP messages, opt-outs, and the in-app privacy-options entry. Only then mark `audience_reviewed` and `consent_messages_configured` true.
- [ ] Create/register your Android app and separate rewarded/interstitial units in your own AdMob account. Set the rewarded unit's configured reward to **one extra life**, with a positive amount. IDs are public identifiers, but do not put signing keys or service credentials in the project.
- [ ] Replace all three production placeholders in `config/ads.cfg` with your actual App ID, rewarded unit ID, and interstitial unit ID. Set the identical App ID in `admob/general/android/app_id`; a mismatch blocks production requests.
- [ ] Validate on an Android test device with `test_ads=true` first: real SDK loading, network/no-fill/load failure, early dismissal, completed reward, duplicate callbacks, app backgrounding, one continue per run, interstitial caps, manifest, memory cleanup, and retained score/statistics. Test-ads SDK behavior has not been validated in this implementation session.
- [ ] Confirm the ads-enabled presets use Gradle and the required network permissions, correct package/version, target SDK, and your private release signing setup. Review actual merged SDK permissions and store data declarations.
- [ ] Only for the final production release set `production_ready=true` and `test_ads=false`; keep `enabled=true`. Export using **Export With Debug unchecked**. Debug builds always override back to the public test units. Placeholder or sample production IDs are refused.
- [ ] Check the release package configuration offline before distribution; don't generate artificial live impressions to validate it. Use registered test devices/test mode for developer QA.
- [ ] Complete AdMob app/account readiness and store review yourself, and retain a way to ship an ads-disabled update. Configuration switches here are packaged into the app, not a remote kill switch.

SSV is not implemented: this is a client-side, local, one-life reward with no backend. Never grant it from a timer, ad loading, impression, click, or dismissal alone. Google-served reward callbacks precede dismissal; mediation is disabled. If adding mediation or valuable/competitive rewards, re-evaluate callback ordering and server-side verification before release. [Google reward-callback semantics](https://developers.google.com/admob/android/rewarded).

## Verification commands and limits

```powershell
godot --headless --path . --script res://tests/ads_test.gd
godot --headless --path . --script res://tests/core_gameplay_test.gd
godot --headless --path . --script res://tests/menu_transition_test.gd
```

All are local fake-provider/no-plugin checks and use isolated `user://neon_hop_test_*.json` saves. They verify consent gating, test ID selection, no presentation during gameplay, pending-form deferral, failure/backoff, cooldowns/session caps, reward token handling, and actual in-place gameplay revival. Android native callbacks, UMP forms, Gradle packaging, and impressions require the manual test-only device setup above. No Android ads build or impression is claimed.

API references used for this adapter: [tagged GDScript API](https://github.com/poingstudios/godot-admob-plugin/tree/v5.1.0/platforms/godot_editor/addons/admob/gdscript/src), [tagged Android converter](https://github.com/poingstudios/godot-admob-plugin/blob/v5.1.0/platforms/android/src/ads/src/main/java/com/poingstudios/godot/admob/ads/converters/GodotDictionaryToJavaObject.kt), and [tagged exporter/settings service](https://github.com/poingstudios/godot-admob-plugin/blob/v5.1.0/platforms/godot_editor/addons/admob/internal/services/project_settings_service.gd). The v5.x documentation is under the vendor's `/5.0/` site; the implementation was checked against **v5.1.0 source** rather than assuming documentation matches every SDK revision.
