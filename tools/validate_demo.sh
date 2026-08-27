#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/d/Godot/aaa"
PROJECT_WIN="$(wslpath -w "$ROOT")"
VISUAL_SCRIPT_WIN="$(wslpath -w "$ROOT/scripts/validate_demo.gd")"

echo "[1/2] Gameplay smoke test"
godot --headless --path "$PROJECT_WIN" -- --smoke-test

echo "[2/2] Visual and real-input test"
godot --path "$PROJECT_WIN" -s "$VISUAL_SCRIPT_WIN"

echo "Validation report: $ROOT/validation/report.json"
