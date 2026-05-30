# dexter

Cross-platform database & data-source management tool, built with Flutter.

## Supported platforms & architectures

| Platform | Architectures | Release artifact |
|----------|---------------|------------------|
| Android  | arm (armeabi-v7a), arm64 (arm64-v8a), x86_64 | per-ABI `.apk` + universal `.aab` |
| iOS      | arm64 | unsigned `.ipa` |
| Linux    | x64, arm64 | `dexter-linux-<arch>.tar.gz` |
| Windows  | x64 | `dexter-windows-x64.zip` |
| macOS    | universal (arm64 + x86_64) | `dexter-macos.zip` |
| Web      | n/a | `dexter-web.zip` |

> Windows is x64 only — Flutter has no official Windows arm64 desktop target; arm64 devices run the x64 build under emulation.

## Install

Pulls the matching artifact from the latest GitHub Release and installs it for your platform.

**Linux / macOS:**

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/dexter/main/install.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/OWNER/dexter/main/install.ps1 | iex
```

Replace `OWNER` with the GitHub owner. Overrides via env vars: `DEXTER_REPO` (owner/repo), `DEXTER_VERSION` (e.g. `v0.1.0`, default latest), `DEXTER_BIN` (Linux symlink dir, default `~/.local/bin`).

| OS | Installs to |
|----|-------------|
| Linux | bundle → `~/.local/share/dexter`, symlink → `~/.local/bin/dexter` |
| macOS | `dexter.app` → `/Applications` (quarantine stripped — unsigned build) |
| Windows | `%LOCALAPPDATA%\Programs\dexter`, added to user PATH |

> Android / iOS / Web are not shell-installable — grab the `.apk` / `.ipa` / web archive from the [Releases](https://github.com/OWNER/dexter/releases) page.

## Build locally

Requires the Flutter SDK (`stable`, Dart `>= 3.12`).

```bash
flutter pub get
# generate freezed / riverpod / json_serializable sources
dart run build_runner build --delete-conflicting-outputs
```

Then build per platform:

```bash
flutter build apk --release --split-per-abi   # Android (arm, arm64, x86_64)
flutter build appbundle --release             # Android Play Store bundle
flutter build ios --release --no-codesign     # iOS (unsigned)
flutter build linux --release                 # Linux (host arch)
flutter build windows --release               # Windows x64
flutter build macos --release                 # macOS universal
flutter build web --release                   # Web
```

## CI: build & release

`.github/workflows/release.yml` builds every platform/architecture and publishes a GitHub Release.

**Trigger:** push a tag matching `v*` (matches the `pubspec.yaml` version), or run manually via `workflow_dispatch`.

```bash
git tag v0.1.0
git push origin v0.1.0
```

Each job runs `build_runner` codegen, builds, and uploads artifacts; the final `release` job attaches them all to the tag's GitHub Release with auto-generated notes.

> **Signing:** iOS, macOS, and Android artifacts are **unsigned**. For store distribution add signing certs / keystore via repository secrets and the matching signing steps.
