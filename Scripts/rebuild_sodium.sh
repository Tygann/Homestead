#!/bin/bash
# Rebuild unmodified libsodium crypto with its upstream safe arc4random backend.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
build_root="$(mktemp -d "${TMPDIR:-/tmp}/homestead-sodium.XXXXXX")"
trap 'rm -rf "$build_root"' EXIT
curl --fail --location --silent --show-error \
  https://download.libsodium.org/libsodium/releases/libsodium-1.0.22.tar.gz \
  -o "$build_root/source.tar.gz"
echo 'adbdd8f16149e81ac6078a03aca6fc03b592b89ef7b5ed83841c086191be3349  '"$build_root/source.tar.gz" | shasum -a 256 -c -
tar -xzf "$build_root/source.tar.gz" -C "$build_root"
source_root="$build_root/libsodium-1.0.22"
for slice in device-arm64 simulator-arm64 simulator-x86_64; do
  arch="${slice#*-}"
  if [[ "$slice" == device-* ]]; then
    sdk=iphoneos
    minimum=-mios-version-min=26.5
  else
    sdk=iphonesimulator
    minimum=-mios-simulator-version-min=26.5
  fi
  sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
  host=aarch64-apple-darwin23
  [[ "$arch" == x86_64 ]] && host=x86_64-apple-darwin23
  mkdir -p "$build_root/$slice"
  cd "$build_root/$slice"
  # Out-of-tree configure preserves upstream platform and CPU feature detection.
  CC="$(xcrun --sdk "$sdk" --find clang)" \
  CPPFLAGS=-DHAVE_SAFE_ARC4RANDOM \
  CFLAGS="-O3 -arch $arch -isysroot $sdk_path $minimum" \
  LDFLAGS="-arch $arch -isysroot $sdk_path $minimum" \
    "$source_root/configure" --host="$host" --prefix="$build_root/install-$slice" \
      --disable-shared cross_compiling=yes
  make -j8 install
  xcrun nm -A -u "$build_root/install-$slice/lib/libsodium.a" > "$build_root/$slice-imports.txt" 2>/dev/null
  if grep -E 'sysrandom.* _fstat$' "$build_root/$slice-imports.txt"; then
    echo 'Unexpected fstat import in rebuilt libsodium' >&2
    exit 1
  fi
done
xcrun lipo -create "$build_root/install-simulator-arm64/lib/libsodium.a" \
  "$build_root/install-simulator-x86_64/lib/libsodium.a" -output "$build_root/simulator.a"
for slice in device-arm64 simulator-arm64; do
  headers="$build_root/install-$slice/include"
  mkdir "$headers/Clibsodium"
  mv "$headers/sodium.h" "$headers/sodium" "$headers/Clibsodium/"
  printf 'module Clibsodium {\n  header "sodium.h"\n  export *\n}\n' > "$headers/Clibsodium/module.modulemap"
done
xcodebuild -create-xcframework \
  -library "$build_root/install-device-arm64/lib/libsodium.a" -headers "$build_root/install-device-arm64/include" \
  -library "$build_root/simulator.a" -headers "$build_root/install-simulator-arm64/include" \
  -output "$build_root/Clibsodium.xcframework"
cp "$source_root/LICENSE" "$repo_root/Vendor/Sodium/libsodium-LICENSE"
# Replace only the generated dependency in this repository after all checks pass.
rm -rf "$repo_root/Vendor/Sodium/Clibsodium.xcframework"
cp -R "$build_root/Clibsodium.xcframework" "$repo_root/Vendor/Sodium/"
