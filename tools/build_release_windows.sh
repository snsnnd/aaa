#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="/mnt/d/Godot/aaa_Release_Windows"
GODOT_DIR="/mnt/d/Godot/Godot_v4.7.2-stable_mono_win64"

echo "======================================================="
echo "✦ 开始构建 Windows Release 独立发布版 (exe+pck) ✦"
echo "======================================================="

mkdir -p "$OUT_DIR"

PROJECT_WIN="$(wslpath -w "$ROOT")"
PCK_WIN="$(wslpath -w "$OUT_DIR/aaa.pck")"

echo "[1/3] 正在导出完整游戏资源包 (aaa.pck)..."
godot --headless --path "$PROJECT_WIN" --export-pack "Windows Desktop" "$PCK_WIN"

echo "[2/3] 正在拷贝 Windows 原生可执行引擎 (aaa.exe) 与运行库..."
cp "$GODOT_DIR/Godot_v4.7.2-stable_mono_win64.exe" "$OUT_DIR/aaa.exe"
cp -r "$GODOT_DIR/GodotSharp" "$OUT_DIR/"

echo "[3/3] 正在生成一键启动脚本..."
cat << 'EOF' > "$OUT_DIR/启动游戏.bat"
@echo off
start "" "%~dp0aaa.exe"
EOF

echo ""
echo "======================================================="
echo "✦ 构建成功！独立发布包目录: D:\\Godot\\aaa_Release_Windows\\"
echo "  包含内容:"
echo "    - aaa.exe (双击直接运行)"
echo "    - aaa.pck (游戏核心资源)"
echo "    - GodotSharp/ (运行库)"
echo "    - 启动游戏.bat"
echo "======================================================="
