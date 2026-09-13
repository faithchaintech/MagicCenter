# MagicCenter

A local macOS menu bar app that turns a physical one-finger press in the Magic Mouse's center strip into middle mouse button 2. Requires macOS 13 or later.

## Use

1. Open MagicCenter.app. The Magic Mouse outline icon in the menu bar opens settings. The Dock icon is hidden by default; toggle “Show in Dock” in the menu at any time without rebuilding or resetting permissions.
2. If requested, enable MagicCenter under System Settings → Privacy & Security → Accessibility. The app retries automatically; reopen it if macOS requires that.
3. Lift your other finger and physically press the center strip. A tap alone does not trigger it.
4. Use the built-in test area; it should say “Middle click received ✓”. Adjust Center width if necessary. Default: middle 24% of the mouse's width, along its full length.
5. Hold and move for a middle drag. Normal scrolling and edge clicks pass through. Launch at login is optional.

Pause or quit from the menu bar. To remove the app, quit it, turn off Launch at login if enabled, and move it to Trash.

## Build and verification

Run `./build.sh` with Xcode command line tools. It creates `build/MagicCenter.app` and signs it ad hoc for local use. An ad-hoc signature changes when the binary changes. After replacing an installed build, reset only this app’s stale grant using `tccutil reset Accessibility local.victor.MagicCenter`, then launch the installed app and grant Accessibility again. Do not validate the app’s permission by launching its executable from an already trusted terminal; launch it through Finder or `open`.

Run `./test.sh` for the gesture and CoreGraphics conversion tests. Run the app executable with `--diagnose` for device enumeration, or `--integration-test` for in-process CoreGraphics conversion tests (no clicks are posted).

## Design and limits

- Uses a native AppKit interface, CoreGraphics event tap, and ServiceManagement for optional launch at login.
- Dynamically loads Apple's private MultitouchSupport framework to read finger coordinates. This interface is undocumented and future macOS versions may require an update. The app fails without intercepting clicks if required symbols are missing.
- Registers only the first connected Magic Mouse for conversion and reads trackpad contact frames to avoid remapping concurrent trackpad clicks. Re-enumerates devices every three seconds and restarts touch readers after wake.
- Quartz click events do not provide a supported physical device identifier. Conversion correlates a fresh one-finger Magic Mouse frame with a hardware mouse press; pressing a separate mouse while resting a finger on the Magic Mouse center can therefore also be converted. Use one pointing device at a time or pause MagicCenter.
- Active drags remain paired even if the gesture is paused or the finger moves away. Quitting sends a middle-button release if needed.
- No network access, analytics, accounts, subscriptions, or external dependencies. Click count is kept only in memory for the current session.
- This is an independent implementation of the requested gesture, not a WheelClick copy. It does not implement WheelClick's other gestures or plugins.

The MultitouchSupport ABI was checked against https://github.com/calftrail/TrackMagic/blob/master/MultitouchSupport.h. WheelClick's description of its center-click gesture and private-API requirement: https://wheelclick.app/.

Compiled and tested locally on macOS 26.6.1 (Intel). Device detection and event-tap startup succeeded. Synthetic logic/event tests do not replace a physical Magic Mouse click test.

## App artwork

`AppIcon.icns` is the embedded application icon. The build script copies it into `Contents/Resources` and Info.plist declares it using `CFBundleIconFile`, so Finder and System Settings can resolve the same artwork. `CreateAppIcon.swift` generates the original artwork and all macOS icon resolutions. `ApplyAppIcon.swift` is retained only as an optional Finder-custom-icon utility and is not used by the current build.

## Package an installer

Run `./build-dmg.sh` from this folder. It builds the app, creates a local `.venv` with the pinned DMG packaging dependency when needed, and writes the styled drag-to-Applications installer to `dist/MagicCenter-1.2.dmg`. Python 3 and macOS disk image tools are required.

The app builds for the current Mac's architecture. The existing packaged release was built on Intel. Packages are locally signed, not Apple-notarized.

## Repository contents

Commit the source files, scripts, icons, background artwork, README and dependency file. `.gitignore` excludes generated `build/`, `dist/`, `.venv/`, and disk images. Upload DMGs to GitHub Releases instead of committing them.

A license has not yet been selected. Add one before publishing if you want to grant reuse rights explicitly.
