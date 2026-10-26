# Android Stress Builds

GitHub Actions builds [stressapptest](https://github.com/stressapptest/stressapptest)
and [stress-ng](https://github.com/stress-ng/stress-ng) for Android with the Android
NDK, and publishes fully static executables as GitHub Releases.

## 中文摘要

本仓库通过 GitHub Actions 自动交叉编译 stressapptest 与 stress-ng 的 Android 版本，
并为每个 ABI 直接发布全静态可执行文件、SHA256 校验文件和许可证文件。

## Releases

Release tags are `stressapptest-<version>` and `stress-ng-<version>` (the upstream
`v`/`V` prefix is removed). Each Release contains one bare executable per ABI plus a
matching `.sha256`, and the applicable license files:

```text
stress-ng-0.22.01-android-arm64-v8a
stress-ng-0.22.01-android-arm64-v8a.sha256
stress-ng-0.22.01-android-armeabi-v7a
stress-ng-0.22.01-android-armeabi-v7a.sha256
stress-ng-0.22.01-android-x86_64
stress-ng-0.22.01-android-x86_64.sha256
LICENSE-stress-ng
```

A scheduled workflow checks the latest upstream release every day at 19:17 UTC and
publishes a new Release only when the upstream version changes. Manual runs are
available from the Actions tab, with optional `version` and `force` inputs.

| ABI | stressapptest | stress-ng |
|---|---|---|
| `arm64-v8a` | API 29 (Android 10) | API 29 (Android 10) |
| `armeabi-v7a` | API 24 (Android 7.0) | API 26 (Android 8.0) |
| `x86_64` | API 24 (Android 7.0) | API 26 (Android 8.0) |

All binaries are fully static `ET_EXEC` (no `PT_INTERP`, no `DT_NEEDED`) and built with
16 KB page alignment. They are plain executables, not PIE, so run them from `adb shell`
or `/data/local/tmp`, not from an app sandbox. A small `getrandom(2)`-based
`arc4random(3)` compatibility layer keeps them working on kernels older than 4.14, where
the NDK r30 static libc would otherwise abort.

## Usage

Download the executable for your ABI, verify it, and push it to the device:

```sh
sha256sum -c stress-ng-0.22.01-android-arm64-v8a.sha256
chmod +x stress-ng-0.22.01-android-arm64-v8a
adb push stress-ng-0.22.01-android-arm64-v8a /data/local/tmp/stress-ng
adb shell chmod 755 /data/local/tmp/stress-ng
adb shell /data/local/tmp/stress-ng --cpu 2 --timeout 30s --metrics-brief

adb push stressapptest-1.0.11-android-arm64-v8a /data/local/tmp/stressapptest
adb shell chmod 755 /data/local/tmp/stressapptest
adb shell /data/local/tmp/stressapptest -s 30 -M 512
```

Some options need root or specific capabilities; see the upstream documentation.

## Licenses

- This repository (workflows and scripts): MIT, see `LICENSE`.
- `stressapptest`: Apache-2.0, see `licenses/stressapptest-Apache-2.0.txt` and
  `licenses/stressapptest-NOTICE`.
- `stress-ng`: GPL-2.0-or-later, see `licenses/stress-ng-GPL-2.0.txt`. The upstream
  commit used for each build is recorded in its Release notes.
