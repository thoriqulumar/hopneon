# Neon Hop — Android release checklist

Prepared on 2026-10-22 for the installed Godot **4.7.2** standard/GDScript editor. Use export templates matching your exact editor build. This is release preparation, **not a completed Android build**: no APK/AAB export, signing, device install, or Play upload has been executed for this task. No private key or signing password was generated.

This checklist describes the checked-in **ads-disabled** presets. For an ads-enabled Android build, first follow [ADMOB_INTEGRATION.md](ADMOB_INTEGRATION.md): install the pinned native plugin, enable Gradle for debug APK too, add the required network permissions, and complete privacy/account setup. The offline-only permission and data-disclosure statements below must be re-reviewed for that build.

## Configured in the repository

- [x] App name `Neon Hop`; initial version name `1.0.0`; version code `1`.
- [x] Editable package placeholder `com.example.neonhop` in both export presets.
- [x] Portrait orientation (`window/handheld/orientation=1`), 540×960 logical viewport, `canvas_items` scaling with `expand`, safe-area UI containers.
- [x] Native screen-touch jumping and left-click/Space/Enter testing. Touch-to-mouse emulation enables native UI buttons; mouse-to-touch emulation is off to avoid duplicate jump events.
- [x] Compatibility renderer; arm64-only packages for the initial phone release. Enable other ABIs only if you intend to support and test them.
- [x] `Android Debug APK`: signed debug APK using the prebuilt template.
- [x] `Android Release AAB`: Gradle AAB, release credentials intentionally blank, target SDK 36.
- [x] Original launcher artwork, separate adaptive layers, monochrome themed icon, and branded boot splash. All PNGs and editable SVG sources are in `assets/android/`.
- [x] Only `VIBRATE` is requested by these presets. Internet/network, location, microphone, camera, and external-storage permissions are disabled; custom permissions are empty. Unlisted permission switches retain Godot's disabled defaults.
- [x] Android automatic user-data backup disabled (`user_data_backup/allow=false`), keeping this project's progress local. This does not prevent users from manually copying data.
- [x] Tests, tooling, and Markdown excluded from packaged resources. Build outputs, signing files, and local credentials ignored by Git.

Public metadata lives in `export_presets.cfg` and `project.godot`; review both when changing the name/version. Android option details: [Godot Android exporter reference](https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformandroid.html).

Run `godot --headless --path . --script res://tools/check_android_release.gd` for a static configuration/artwork/signing-field check. It does not build an APK/AAB or inspect a generated manifest. The Godot configuration check and existing scene/gameplay tests are separate from the manual Android gates below.

## Manual setup — required before either export

- [ ] Install **OpenJDK 17** and point **Editor Settings → Export → Android → Java SDK Path** at its root, not `bin/java.exe`.
- [ ] Configure **Android SDK Path** to your SDK root. Install Platform Tools (including `adb`), current Command-line Tools, Build Tools **35.0.1**, Platform **35**, CMake **3.10.2.4988404**, and NDK **28.1.13356709**, following the requirements for the selected Godot version. Accept SDK licenses.
- [ ] Also install **Android SDK Platform 36** for the release target. Ensure the installed Godot/Gradle template supports compiling for this target; upgrade editor/templates together if required.
- [ ] In **Editor → Manage Export Templates**, install the templates matching the editor exactly. For this checkout's installed editor that is `4.7.2.stable`; do not mix another Godot version's APKs or source template.
- [ ] Import the project once in the editor, wait for resource imports, then confirm **Project → Export** shows both prepared presets.
- [ ] Replace `com.example.neonhop` with an identifier you control in **both** presets before distribution, for example `com.yourstudio.neonhop`. This is public configuration, not a secret. Use lowercase identifiers without spaces. Keep the published identifier stable for updates.
- [ ] Set a new `version/code` for every uploaded release, and synchronize `version/name` with `application/config/version` in `project.godot`.

The SDK/JDK list comes from the [Godot 4.7 Android setup guide](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html). Gradle may need internet during setup/dependency download; the exported game remains fully offline.

**Observed on this machine:** matching `4.7.2.stable` Android templates exist. The inspected SDK contains platforms only through 33 and build tools only through 33.0.0; `java` on PATH resolves to OpenJDK 11. These observations do not verify a configured JDK 17, complete SDK, working signing setup, or successful export. Installation/configuration above remains manual.

**Play target requirement:** as of this checklist date, ordinary new phone apps and updates require target API 36 or higher. The AAB preset explicitly selects 36; recheck [Google Play's current target API requirement](https://developer.android.com/google/play/requirements/target-sdk) before upload. A debug APK using the older prebuilt template is not evidence that the release target works.

## Launcher icons and splash

| File in `assets/android/` | Size | Use |
| --- | --- | --- |
| `launcher.png` | 512×512 | Legacy launcher and project icon |
| `adaptive_foreground.png` | 432×432 | Transparent character/orbit layer |
| `adaptive_background.png` | 432×432 | Opaque full-bleed dark layer |
| `adaptive_monochrome.png` | 432×432 | White silhouette on transparency for themed launchers |
| `boot_splash.png` | 540×960 | Godot startup screen; proportional scaling with matching dark background |

The important adaptive foreground art fits inside the centered 264-pixel safe circle. The system splash uses the foreground icon; Gradle also applies the configured dark system-splash color. The Godot boot splash follows system startup and uses the branded PNG.

To edit the artwork, change the SVG sources and regenerate the PNGs from the project root:

```powershell
godot --headless --path . --script res://tools/generate_android_art.gd
```

- [ ] Check launcher masks (circle, rounded square, squircle), Android themed icons, Android 12+ system splash, and the Godot splash on a device. OS splash behavior differs from a desktop startup window; no Android screenshot verification has been performed.

## Debug APK — manual export and install

1. Complete SDK/JDK/template setup and configure Godot's local debug keystore in **Editor Settings → Export → Android** if it is not already available. Keep any locally generated signing material outside the repository.
2. Create the ignored `build/` directory in the project root.
3. In **Project → Export**, select **Android Debug APK**, then **Export Project**. Keep **Export With Debug** enabled and choose `build/neon-hop-debug.apk`.
4. For an offline permission check, leave remote debugging and network filesystem deployment disabled. Debug deployment options can add network permissions even when the public preset disables Internet.
5. Enable USB debugging on a test phone, authorize your computer, then install the APK:

```powershell
adb devices
adb install -r "build/neon-hop-debug.apk"
```

After setup, the equivalent command-line export is:

```powershell
godot --headless --path . --export-debug "Android Debug APK" "build/neon-hop-debug.apk"
```

- [ ] Confirm the command exits successfully and the APK actually exists before recording a successful build.
- [ ] Test tapping, mouse-independent UI controls, pause/resume, audio, haptics, save/relaunch, and different safe areas.
- [ ] If installation reports a signing mismatch, use a separate debug package identifier or intentionally uninstall the old app. Uninstalling generally removes local progress; do not do it casually to fix an update error.

## Release signing — manual, outside the repository

For Play distribution, create an **upload keystore** and use Play App Signing to manage the distribution signing key. Protect and back up your upload key and passwords. See [Android's signing guide](https://developer.android.com/studio/publish/app-signing).

The following is an example for you to run manually after creating a secure directory outside this checkout. It has **not** been run. `keytool` prompts interactively; do not add password arguments or paste passwords into chat, scripts, source files, or shell history.

```powershell
keytool -genkeypair -v -keystore "C:\SecureSigning\neon-hop-upload.jks" -alias neonhop-upload -keyalg RSA -keysize 2048 -validity 10000
```

- [ ] Supply real identity details yourself at the prompts. Use the same key and keystore password for Godot compatibility. Store the password in your password manager.
- [ ] Keep the keystore outside the project and backed up securely. `.gitignore` is a safeguard, not secure storage.
- [ ] Configure signing **locally**, preferably using protected CI/environment settings that Godot recognizes:
  - `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`: absolute keystore path.
  - `GODOT_ANDROID_KEYSTORE_RELEASE_USER`: key alias.
  - `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`: secret supplied by your secret manager or protected CI variable.
- [ ] If using the editor's Keystore/Release fields, inspect local files and the source-control diff before committing. Keep release paths/passwords out of the tracked preset. Godot's `.godot/export_credentials.cfg` is already excluded with `.godot/`.
- [ ] Never use a debug key to publish a release. Preserve signing identity for future updates.

## Release AAB — manual export

1. Install the Android Gradle build template from **Project → Install Gradle Build Template** (called **Install Android Build Template** in some Godot 4 versions). Godot generates `android/build/`; it is ignored and not included in this preparation. Follow [Godot's Gradle setup](https://docs.godotengine.org/en/4.7/tutorials/export/android_gradle_build.html).
2. Select **Android Release AAB**. Keep **Use Gradle Build** enabled and **Export Format = AAB**. Resolve all SDK/template/signing errors in the export dialog.
3. Verify target SDK 36, package identifier, version values, ABI selection, and local signing credentials. Do not enable debug deployment options.
4. Export `build/neon-hop-release.aab` with **Export With Debug unchecked**.

```powershell
godot --headless --path . --export-release "Android Release AAB" "build/neon-hop-release.aab"
```

- [ ] Confirm successful export and artifact existence. An AAB is not directly installable with `adb install`; use Play internal testing or Android `bundletool` to produce signed device APKs.
- [ ] Verify the bundle signature with `jarsigner -verify -verbose -certs "build/neon-hop-release.aab"`. Confirm the expected upload certificate, not merely that a signature is present.
- [ ] Inspect the final merged manifest and actual APK permissions with Android Studio APK Analyzer or `apkanalyzer manifest permissions` on device APKs. Confirm no network, storage, microphone, camera, or location permission slipped in through templates/debug flags. `VIBRATE` is intentional; disable it only if removing Android haptics.
- [ ] Upload to Play **internal testing** manually, review platform validation, and test the store-generated install before production. No upload is performed by these instructions.

## Device and submission gate — all manual

- [ ] Portrait behavior on a physical phone; cutouts, gesture navigation, 16:9 and tall screens; recent Android versions and a lower-end supported device. Android large-screen/windowing policies may override orientation requests, so also check tablet/foldable behavior.
- [ ] Adaptive/themed icons and cold-start splash look correct without clipping.
- [ ] Tap once produces one jump; tapping UI does not jump the character. Sound/volume/mute, optional haptics, and shake toggles work.
- [ ] Airplane-mode play works; save/backup survives force-stop, relaunch, and a correctly signed update; pause/resume behaves correctly.
- [ ] Measure frame time and memory on the intended minimum device; 60 FPS is a target, not a verified Android result.
- [ ] Test the final release artifact's native-library/page-size compatibility using current Play validation, including 16 KB page-size devices. Matching templates alone do not prove this device test passed.
- [ ] Complete store listing, screenshots, content rating, privacy/data-safety declarations, app access details, and testing/verification requirements in your own Play Console.
- [ ] Record editor/template/SDK/JDK versions, artifact hash, package/version code, signing certificate fingerprint, actual device results, and export output in your release records. Never record passwords or private keys there.
