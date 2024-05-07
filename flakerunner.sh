#!/usr/bin/env bash

pushd $(dirname $0)/"$1"/export
nix run --show-trace -v -I ../.. .#"$1"-export
popd
