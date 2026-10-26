# Patches

Optional minimal patches for upstream sources, grouped by tool:

```text
patches/stress-ng/*.patch
patches/stressapptest/*.patch
```

They are applied with `patch -p1` inside the extracted upstream source directory, in
lexical order. Keep each patch as small as possible, put the reason in the patch
header, and make sure the result stays license-compatible with the upstream project.

There are currently no patches for either tool. `stress-ng` is built at API 26 on
`armeabi-v7a` and `x86_64` precisely to avoid a patch for bionic's API-26-only
`quotactl()` and SysV `shm*()` declarations.
