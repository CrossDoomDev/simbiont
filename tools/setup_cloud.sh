#!/usr/bin/env bash
# Install the same native editor used by this project, without machine-specific paths.
set -euo pipefail

godot_version="${GODOT_VERSION:-4.7.1}"
install_dir="${GODOT_INSTALL_DIR:-${HOME}/.local/bin}"
archive_name="Godot_v${godot_version}-stable_linux.x86_64.zip"
release_base="https://github.com/godotengine/godot-builds/releases/download/${godot_version}-stable"
download_dir="$(mktemp -d -t symbiont-godot.XXXXXXXX)"
trap 'rm -rf -- "$download_dir"' EXIT

mkdir -p "$install_dir"
curl --fail --location --retry 3 --output "$download_dir/godot.zip" "$release_base/$archive_name"
python3 -m zipfile -e "$download_dir/godot.zip" "$download_dir/editor"
install -m 755 "$download_dir/editor/Godot_v${godot_version}-stable_linux.x86_64" "$install_dir/godot"
"$install_dir/godot" --version
printf 'Godot installed at %s/godot\n' "$install_dir"
