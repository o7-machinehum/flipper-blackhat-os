#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

docker run --rm --platform linux/arm/v7 \
  --volume "$repo_root:/src" --workdir /src \
  --env DEBIAN_FRONTEND=noninteractive \
  kalilinux/kali-rolling:latest bash -euo pipefail -c '
    test "$(dpkg --print-architecture)" = armhf
    apt-get update
    apt-get install -y --no-install-recommends \
      build-essential cmake git ca-certificates libicu-dev

    cmake -S package/bhtui -B package/bhtui/build \
      -DCMAKE_BUILD_TYPE=Release
    cmake --build package/bhtui/build --target bhtui --parallel 2

    ldd package/bhtui/build/bhtui
    # An unsupported option prints usage and exits 2 without opening the TUI.
    package/bhtui/build/bhtui --help || test "$?" -eq 2
  '
