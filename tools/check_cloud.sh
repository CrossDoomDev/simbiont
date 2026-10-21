#!/usr/bin/env bash
# Run from any working directory; GODOT_BIN can override the editor executable.
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
cd "$project_dir"
mkdir -p artifacts/ci

"$godot_bin" --headless --path . --editor --import --quit 2>&1 | tee artifacts/ci/import.log
if grep -Eq '^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:' artifacts/ci/import.log; then
    exit 1
fi

for test_name in check_scripts test_progress test_gameplay test_touch; do
    "$godot_bin" --headless --path . --script "res://tests/${test_name}.gd" 2>&1 | tee "artifacts/ci/${test_name}.log"
    if grep -Eq 'SCRIPT ERROR:|CHECK FAILED:|GAMEPLAY_CHECK_FAILED:|TOUCH_CHECK_FAILED:' "artifacts/ci/${test_name}.log"; then
        exit 1
    fi
    case "$test_name" in
        check_scripts) marker='SCRIPT_CHECKS'; unit='files' ;;
        test_progress) marker='PROGRESS_TESTS'; unit='checks' ;;
        test_gameplay) marker='GAMEPLAY_TESTS'; unit='checks' ;;
        test_touch) marker='TOUCH_TESTS'; unit='checks' ;;
    esac
    grep -Eq "^${marker}: [1-9][0-9]* ${unit}, 0 failures$" "artifacts/ci/${test_name}.log"
done
python3 tools/validate_art.py | tee artifacts/ci/art.log
