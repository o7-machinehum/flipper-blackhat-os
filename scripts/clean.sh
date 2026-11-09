#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

rm -rf --one-file-system -- \
    armbian/output armbian/cache armbian/.tmp armbian/userpatches \
    images package/bhtui/build package/bhtui/build-*
