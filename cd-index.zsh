# cd-index.zsh —— 用「序号」进入当前目录下的第 N 个文件夹（zsh 版）
#
#   cd ./3    == cd ./'第 3 个文件夹的名字'
#   cd ./0    # 只列出编号
#
# 安装见仓库 README，或直接：
#   source /path/to/cd-index/cd-index.zsh

_cd_index_list() {
  local i=1 d
  for d in "$@"; do
    printf '  %2d) %s\n' "$i" "${d%/}"
    (( i++ )) || true
  done
}

_cd_index_do() {
  local idx=$((10#$1))
  local -a dirs

  if [[ ${CD_INDEX_ALL:-0} == 1 ]]; then
    dirs=( *(ND/) )   # N: 无匹配时为空；D: 含隐藏项；/: 只取目录
  else
    dirs=( *(N/) )
  fi

  local total=${#dirs[@]}

  if (( total == 0 )); then
    printf 'cd: 当前目录下没有子文件夹\n' >&2
    return 1
  fi

  if (( idx == 0 )); then
    printf '当前目录下的子文件夹（共 %d 个，用 cd ./N 进入）：\n' "$total" >&2
    _cd_index_list "${dirs[@]}"
    return 0
  fi

  if (( idx < 1 || idx > total )); then
    printf 'cd: 序号 %d 超出范围：当前目录有 %d 个子文件夹，可用 1..%d\n' \
      "$idx" "$total" "$total" >&2
    _cd_index_list "${dirs[@]}"
    return 1
  fi

  builtin cd -- "${dirs[idx]%/}"
}

cd() {
  if [[ $# -eq 1 && $1 =~ '^\./([0-9]+)/?$' ]]; then
    if [[ -d $1 ]]; then
      builtin cd -- "$1"
      return
    fi
    _cd_index_do "${match[1]}"
    return
  fi
  builtin cd "$@"
}
