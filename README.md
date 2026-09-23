# LiveIconLab

Minimal research harness for testing whether iPadOS 27 SpringBoard can map a third-party app bundle ID to Apple's live Clock icon class.

## Target

- Device: iPad
- Runtime target: iPadOS 27
- Test app bundle ID: `com.goldcreative.liveiconlab`
- Live icon class under test: `SBHClockApplicationIcon`
- SpringBoard selector under test: `iconClassForApplicationWithBundleIdentifier:`

## What this repository builds

The workflow builds two artifacts:

1. `LiveIconLab-unsigned.ipa` — a tiny unsigned iPad app.
2. `LiveIconHook.dylib` — a SpringBoard-side research hook that replaces the icon class only for `com.goldcreative.liveiconlab`.

The hook resolves SpringBoardHome classes dynamically at runtime, so it does not link against a copied private framework.

## Expected experiment

When `LiveIconHook.dylib` is loaded into the SpringBoard process before the app icon model is rebuilt, the hook asks SpringBoard to use `SBHClockApplicationIcon` for `com.goldcreative.liveiconlab`.

Success condition:

- LiveIconLab still launches LiveIconLab when tapped.
- Its Home Screen icon is rendered by Apple's live Clock icon class and visibly animates.

If the iPadOS 27 selector/class names differ, the hook fails closed and logs the missing runtime symbol instead of replacing arbitrary icon behavior.

## Important runtime note

The unsigned IPA and the SpringBoard dylib are separate pieces. An unsigned IPA does not by itself provide a way to load code into SpringBoard on a stock iPadOS 27 device. This repository intentionally keeps the app/build harness separate from whatever legitimate research loader or device environment is used for SpringBoard-side execution.

## Build

GitHub Actions runs `Scripts/build.sh` on macOS and uploads the IPA and dylib as workflow artifacts.

For local macOS/Xcode builds:

```bash
chmod +x Scripts/build.sh
Scripts/build.sh
```

Output:

```text
build/LiveIconLab-unsigned.ipa
build/LiveIconHook.dylib
build/build-manifest.txt
```

## References

This PoC is based on current reverse-engineering evidence around:

- `SBHClockApplicationIcon`
- `SBHClockApplicationIconImageView : SBLiveIconImageView`
- `SBHIconModel iconClassForApplicationWithBundleIdentifier:`

The repository does not redistribute Apple binaries or private frameworks.
