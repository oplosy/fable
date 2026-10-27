#!/usr/bin/env bash
# Runs every test suite headless at a fixed 60 fps (no real-time waiting).
# Usage: tests/run_all.sh [suite_name ...]   e.g. tests/run_all.sh test_melee
# Set GODOT to override the Godot binary.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Users/mesut/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"

if [ $# -gt 0 ]; then
	suites=("$@")
else
	suites=()
	for file in tests/test_*.gd; do
		name=$(basename "$file" .gd)
		[ "$name" = test_case ] || suites+=("$name")
	done
fi

failed=()
for suite in "${suites[@]}"; do
	output=$("$GODOT" --headless --fixed-fps 60 --path . -s "res://tests/$suite.gd" 2>&1)
	code=$?
	# The exit code is the verdict; the grep catches errors printed after quit().
	if [ $code -ne 0 ] || grep -q "^FAIL\|SCRIPT ERROR" <<< "$output"; then
		failed+=("$suite")
		echo "FAIL $suite"
		grep "^FAIL\|SCRIPT ERROR\|ERROR:" <<< "$output" | sed 's/^/    /'
	else
		echo "ok   $suite"
	fi
done

if [ ${#failed[@]} -gt 0 ]; then
	echo "${#failed[@]} of ${#suites[@]} suites failed: ${failed[*]}"
	exit 1
fi
echo "All ${#suites[@]} suites passed."
