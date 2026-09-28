# cd-index.bash —— 用「序号」进入当前目录下的第 N 个文件夹
#
#   cd ./3        # == cd ./'第 3 个文件夹的名字'
#   cd ./3/       # 同上（允许结尾斜杠）
#   cd ./0        # 只列出编号，不跳转（方便查看 1..N 分别是哪个文件夹）
#
# 规则：
#   * 只把「目录」计入编号，文件不计数
#   * 排序与 ls 相同：按当前 locale 的字典序
#   * 隐藏目录默认不计数；CD_INDEX_ALL=1 时计入（包含 .git 之类）
#   * 其它任何用法都原样交给内置 cd：cd、cd -、cd ..、cd /tmp、cd ~/x …
#   * 若当前目录下真的存在名为 "3" 的目录，则 cd ./3 仍进入它（不破坏原语义）
#
# 安装见仓库 README，或直接：
#   source /path/to/cd-index/cd-index.bash

# 列出编号 -> 目录名（供 cd ./0 或报错时使用）
_cd_index_list() {
  local i=1 d
  for d in "$@"; do
    printf '  %2d) %s\n' "$i" "${d%/}"
    (( i++ )) || true
  done
}

_cd_index_do() {
  local idx=$((10#$1))   # 10# 避免 "08" 被当成八进制
  local -a dirs=()
  local restore_nullglob restore_dotglob

  # 临时开 nullglob（无匹配时得到空数组而不是字面量 "*/"）
  restore_nullglob=$(shopt -p nullglob)
  restore_dotglob=$(shopt -p dotglob)
  shopt -s nullglob
  [[ ${CD_INDEX_ALL:-0} == 1 ]] && shopt -s dotglob
  dirs=( */ )
  eval "$restore_nullglob"
  eval "$restore_dotglob"

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

  local target=${dirs[idx-1]%/}
  builtin cd -- "$target"
}

cd() {
  if [[ $# -eq 1 && $1 =~ ^\./([0-9]+)/?$ ]]; then
    # 真有同名目录时按原意处理，保证不改变正常行为
    if [[ -d $1 ]]; then
      builtin cd -- "$1"
      return
    fi
    _cd_index_do "${BASH_REMATCH[1]}"
    return
  fi
  builtin cd "$@"
}
