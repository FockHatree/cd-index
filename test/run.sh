#!/usr/bin/env bash
# cd-index 统一测试入口：先跑 bash 套件，再跑 zsh 套件；任一失败则整体失败。
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
fail=0

run() { # 名称 命令...
  local name=$1; shift
  printf '\n========== %s ==========\n' "$name"
  if "$@"; then
    printf -- '---- %s: 通过\n' "$name"
  else
    printf -- '---- %s: 失败\n' "$name"
    fail=1
  fi
}

run "bash 套件" bash "$HERE/bash.sh"

if command -v zsh >/dev/null 2>&1; then
  run "zsh 套件" zsh "$HERE/zsh.zsh"
else
  printf '\n========== zsh 套件 ==========\n跳过：未安装 zsh\n'
fi

printf '\n================ 汇总 ================\n'
if (( fail )); then printf '结果：有测试失败\n'; else printf '结果：全部通过\n'; fi
exit "$fail"
