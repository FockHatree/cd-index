#!/usr/bin/env bash
# cd-index 安装脚本：把 cd ./N 装到 bash 与 zsh（oh-my-zsh）
#
#   ./install.sh                  # 安装（bash + zsh）
#   ./install.sh --zsh-only       # 只装 zsh
#   ./install.sh --bash-only      # 只装 bash
#   ./install.sh --dry-run        # 只打印将要做的改动，不落盘
#   ./install.sh --uninstall      # 卸载（移除托管块与 shim）
#
# 特性：
#   * 幂等：重复执行或改动仓库路径后重跑，只会更新那一段托管内容
#   * 会清理历史遗留的裸 source 行（例如手动 echo >> ~/.bashrc 加的那种）
#   * 不做全局 git/系统配置改动，所有写入都会逐条打印出来
set -euo pipefail

VERSION=0.1.0
BEGIN_MARK='# >>> cd-index >>>'
END_MARK='# <<< cd-index <<<'

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

MODE=install
DO_BASH=1
DO_ZSH=1
DRY=0

usage() {
  sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  printf '\n当前仓库路径: %s\n' "$REPO"
}

while (($#)); do
  case $1 in
    -h|--help)      usage; exit 0 ;;
    -u|--uninstall) MODE=uninstall ;;
    -n|--dry-run)   DRY=1 ;;
    --bash-only)    DO_ZSH=0 ;;
    --zsh-only)     DO_BASH=0 ;;
    -V|--version)   printf 'cd-index %s\n' "$VERSION"; exit 0 ;;
    *) printf '未知参数: %s（用 --help 查看用法）\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

say()  { printf '%s\n' "$*"; }
act()  { printf '  $ %s\n' "$*"; if (( ! DRY )); then "$@"; fi; }

# 删除 BEGIN/END 托管块，以及匹配 legacy 的裸 source 行
strip_file() { # 文件 legacy正则
  local f=$1 legacy=$2
  [[ -f $f ]] || return 0
  local tmp; tmp=$(mktemp) || return 1
  # legacy 用 [.] 而不是 \. —— awk 的 -v 字符串里 \. 会触发 "escape sequence" 警告
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" -v legacy="$legacy" '
    $0 == b { inblock = 1; next }
    $0 == e { inblock = 0; next }
    inblock { next }
    $0 ~ legacy { removed++; next }
    /^[[:space:]]*$/ { blanks++; next }   # 空行延迟输出，避免删块后留下孤立空行
    { while (blanks > 0) { print ""; blanks-- } print }
    END { if (removed) printf "  （已移除 %d 行历史遗留的 source）\n", removed > "/dev/stderr" }
  ' "$f" > "$tmp"
  if cmp -s "$f" "$tmp"; then rm -f "$tmp"; return 0; fi
  act mv "$tmp" "$f"
  (( DRY )) && rm -f "$tmp"   # dry-run 下 act 不会执行 mv，别把临时文件留下
  return 0
}

# 目标 rc 文件能写吗？返回非 0 表示跳过
rc_writable() { # 文件
  local f=$1
  if [[ -e $f ]]; then
    [[ -w $f ]] || { say "  跳过：$f 不可写"; return 1; }
  else
    ( : >> "$f" ) 2>/dev/null || { say "  跳过：无法创建 $f"; return 1; }
  fi
  return 0
}

append_block() { # 文件 目标
  local f=$1 target=$2
  if (( DRY )); then
    printf '  $ 追加托管块到 %s:\n      %s\n      source "%s"\n      %s\n' \
      "$f" "$BEGIN_MARK" "$target" "$END_MARK"
    return 0
  fi
  {
    printf '\n%s\n' "$BEGIN_MARK"
    printf 'source "%s"\n' "$target"
    printf '%s\n' "$END_MARK"
  } >> "$f"
}

install_bash() {
  local rc=$HOME/.bashrc legacy='cd-index[.](bash|zsh)'
  say "[bash] 目标: $rc"
  rc_writable "$rc" || return 0
  strip_file "$rc" "$legacy"
  append_block "$rc" "$REPO/cd-index.bash"
  say "  -> source $REPO/cd-index.bash"
}

install_zsh() {
  local custom=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
  if [[ -d $custom ]]; then
    say "[zsh]  检测到 oh-my-zsh，使用自动加载目录: $custom"
    act ln -sfn "$REPO/cd-index.plugin.zsh" "$custom/cd-index.zsh"
    say "  -> $custom/cd-index.zsh -> $REPO/cd-index.plugin.zsh"
    # 顺手清掉 .zshrc 里可能存在的托管块，避免重复加载
    strip_file "$HOME/.zshrc" 'cd-index[.](bash|zsh)'
  else
    say "[zsh]  未检测到 oh-my-zsh，写入 ~/.zshrc"
    local rc=$HOME/.zshrc
    rc_writable "$rc" || return 0
    strip_file "$rc" 'cd-index[.](bash|zsh)'
    append_block "$rc" "$REPO/cd-index.zsh"
  fi
}

uninstall_all() {
  if (( DO_BASH )); then
    say "[bash] 清理 $HOME/.bashrc"
    strip_file "$HOME/.bashrc" 'cd-index[.](bash|zsh)'
  fi
  if (( DO_ZSH )); then
    local custom=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
    say "[zsh]  清理 $HOME/.zshrc 与 $custom/cd-index.zsh"
    strip_file "$HOME/.zshrc" 'cd-index[.](bash|zsh)'
    if [[ -L $custom/cd-index.zsh || -f $custom/cd-index.zsh ]]; then
      act rm -f "$custom/cd-index.zsh"
    fi
  fi
}

printf 'cd-index %s  %s\n' "$VERSION" "$REPO"
(( DRY )) && say '（dry-run：只打印，不写入）'

if [[ $MODE == uninstall ]]; then
  uninstall_all
  say "卸载完成，重开终端或执行 exec \$SHELL 生效。"
else
  if (( ! DRY )); then
    [[ -r $REPO/cd-index.bash ]] || { say "缺少 $REPO/cd-index.bash" >&2; exit 1; }
    [[ -r $REPO/cd-index.zsh  ]] || { say "缺少 $REPO/cd-index.zsh"  >&2; exit 1; }
  fi
  (( DO_BASH )) && install_bash
  (( DO_ZSH ))  && install_zsh
  if (( DRY )); then
    say '（dry-run 结束，上面就是将要做的改动）'
  else
    say "安装完成。重开终端，或执行 exec \$SHELL 后即可使用: cd ./3"
  fi
fi
