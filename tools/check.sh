#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
unset UKI_META_PROXY_URL LLAMA_API_KEY
godot_bin="${GODOT_BIN:-godot}"
check_logs="$(mktemp -d)"
trap 'rm -rf "$check_logs"' EXIT
run_godot() {
    local name="$1"
    shift
    "$godot_bin" --headless --path "$repo_dir" "$@" 2>&1 | tee "$check_logs/$name.log"
    if rg -q '^(SCRIPT ERROR:|ERROR:)' "$check_logs/$name.log"; then
        printf 'Godot reported errors in %s\n' "$name" >&2
        return 1
    fi
}
run_godot import --editor --import
run_godot core --script tests/test_core.gd
run_godot game --script tests/test_game.gd
run_godot meta --script tests/test_meta_adapter.gd
run_godot smoke --quit-after 10
python3 -m unittest discover -s tests -p 'test_*.py' -v
