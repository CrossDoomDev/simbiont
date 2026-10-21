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

for test_name in check_scripts test_fonts test_progress test_gameplay test_touch test_ship test_combat test_caves test_ui_layout test_audio; do
    extra_args=()
    if [[ "$test_name" == test_audio ]]; then
        extra_args=(-- --audio-test)
    fi
    "$godot_bin" --headless --path . --script "res://tests/${test_name}.gd" "${extra_args[@]}" 2>&1 | tee "artifacts/ci/${test_name}.log"
    if grep -Eq '^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|CHECK FAILED:|[A-Z_]+_CHECK_FAILED:' "artifacts/ci/${test_name}.log"; then
        exit 1
    fi
    case "$test_name" in
        check_scripts) marker='SCRIPT_CHECKS'; unit='files' ;;
        test_fonts) marker='FONT_TESTS'; unit='checks' ;;
        test_progress) marker='PROGRESS_TESTS'; unit='checks' ;;
        test_gameplay) marker='GAMEPLAY_TESTS'; unit='checks' ;;
        test_touch) marker='TOUCH_TESTS'; unit='checks' ;;
        test_ship) marker='SHIP_TESTS'; unit='checks' ;;
        test_combat) marker='COMBAT_TESTS'; unit='checks' ;;
        test_caves) marker='CAVE_TESTS'; unit='checks' ;;
        test_ui_layout) marker='UI_LAYOUT_TESTS'; unit='checks' ;;
        test_audio) marker='AUDIO_TESTS'; unit='checks' ;;
    esac
    grep -Eq "^${marker}: [1-9][0-9]* ${unit}, 0 failures$" "artifacts/ci/${test_name}.log"
done
python3 tools/validate_art.py | tee artifacts/ci/art.log
python3 tools/check_host_animation.py | tee artifacts/ci/host_animation.log
"$godot_bin" --headless --path . -- --runtime-test 2>&1 | tee artifacts/ci/runtime.log
if grep -Eq '^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:' artifacts/ci/runtime.log; then
    exit 1
fi
grep -Eq '^RUNTIME_TESTS: [1-9][0-9]* checks, 0 failures$' artifacts/ci/runtime.log
