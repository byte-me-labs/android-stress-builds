# Patches

Optional minimal patches for upstream sources, grouped by tool:

```text
patches/stress-ng/*.patch
patches/stressapptest/*.patch
```

They are applied with `patch -p1` inside the extracted upstream source directory, in
lexical order. A patch that no longer applies is skipped with a warning instead of
failing the build, so the build keeps following upstream releases once a fix lands
upstream. Keep each patch as small as possible, put the reason in the patch header,
and make sure the result stays license-compatible with the upstream project.

One patch is currently carried:

- `stress-ng/0001-pty-bionic-termios.patch` — fixes the `struct termios`
  include-guard breakage introduced in stress-ng V0.22.02 on bionic/Android.

`stress-ng` is built at API 26 on `armeabi-v7a` and `x86_64` precisely to avoid a
patch for bionic's API-26-only `quotactl()` and SysV `shm*()` declarations.
