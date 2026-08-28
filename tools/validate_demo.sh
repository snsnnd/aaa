#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/d/Godot/aaa"
PROJECT_WIN="$(wslpath -w "$ROOT")"
VISUAL_SCRIPT_WIN="$(wslpath -w "$ROOT/scripts/validate_demo.gd")"

echo "[1/4] Gameplay smoke test"
godot --headless --path "$PROJECT_WIN" scenes/main.tscn -- --smoke-test

echo "[2/4] Roguelike systems validation (map/save/cards/traits/boss phases/telemetry)"
godot --headless --path "$ROOT" -s "$ROOT/tools/validate_roguelike.gd"

echo "[3/4] Three-build archetype validation"
godot --headless --path "$ROOT" -s "$ROOT/tools/validate_three_builds.gd"

echo "[4/4] Visual and real-input test"
godot --path "$PROJECT_WIN" -s "$VISUAL_SCRIPT_WIN"

echo "Validation report: $ROOT/validation/report.json"
