# Homestead's iOS Sodium package

The Swift sources are unmodified swift-sodium **0.11.0**, commit
`cfd195c76882aa9b997560ca7cb95d72fbf5db00`, under the included ISC license.
The local package replaces only its prebuilt C dependency and limits supported
platforms to Homestead's iOS device/simulator targets. Crypto APIs and normal
`sodium_init()` initialization are unchanged.

`Clibsodium.xcframework` is built from unmodified **libsodium 1.0.22** using
`Scripts/rebuild_sodium.sh` at the repository root. The script verifies the source
archive SHA-256, runs upstream configure for each architecture, and selects
upstream's `HAVE_SAFE_ARC4RANDOM` backend. Apple provides `arc4random_buf`; no
custom RNG or crypto implementation is introduced. Device arm64 and simulator
arm64/x86_64 slices target iOS 26.5. Rebuild with Xcode selected via xcode-select.

The upstream default random-device backend imports `fstat` for `/dev/random`,
which has no applicable approved required reason. Choosing the upstream safe
arc4random backend removes this use instead of adding an inaccurate manifest
reason. The unused internal-RNG archive member may still import `fstat`; it must
remain absent from the **final Release executable**. Verify that on every update,
along with encrypted webhook roundtrip, tamper rejection, and the official
secretbox interoperability vector in `HAClientHardeningTests`.

A dependency update must refresh both source provenance and generated binaries;
do not restore the upstream prebuilt XCFramework without repeating this audit.
The build is reproducible from pinned source and flags; byte-identical output
across Xcode/toolchain versions is not promised.

References:

- [Upstream safe RNG backend](https://github.com/jedisct1/libsodium/blob/1.0.22-RELEASE/src/libsodium/randombytes/sysrandom/randombytes_sysrandom.c)
- [Upstream Apple build recipes](https://github.com/jedisct1/libsodium/blob/1.0.22-RELEASE/dist-build/apple-xcframework.sh)
- [Apple's system RNG uses arc4random_buf](https://developer.apple.com/documentation/swift/systemrandomnumbergenerator)
- [Apple required-reason APIs](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
