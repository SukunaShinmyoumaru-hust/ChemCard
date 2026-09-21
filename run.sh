#!/usr/bin/env bash
# 快速调试：debug 构建 → 打包 → 直接打开，改完代码一条命令重跑
set -euo pipefail
cd "$(dirname "$0")"
bash build.sh debug
open dist/ChemCards.app
