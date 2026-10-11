#!/usr/bin/env bash
# Entry point: runs the numbered build steps in order.
set -euxo pipefail

for step in /ctx/[0-9][0-9]-*.sh; do
    echo "::group:: ${step##*/}"
    bash "$step"
    echo "::endgroup::"
done
