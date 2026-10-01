#!/usr/bin/env bash
# Run yazi with only this plugin loaded
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
config=$(mktemp -d)
trap 'rm -rf "$config"' EXIT

mkdir -p "$config/plugins"
ln -s "$repo" "$config/plugins/lf.yazi"
echo 'require("lf"):setup()' > "$config/init.lua"

YAZI_CONFIG_HOME=$config yazi "$@"
