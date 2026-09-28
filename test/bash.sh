#!/usr/bin/env bash
# cd-index 的 bash 自测。用法: bash test/bash.sh
#
# 期望值全部从 ls 现算（不硬编码顺序），所以换 locale 也不会误报。
set -u

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd -- "$HERE/.." && pwd)

# 优先用 mktemp；失败则退回仓库内的隐藏目录（两者都在 EXIT 时清理）
TMPBASE=$(mktemp -d 2>/dev/null) || TMPBASE=$HERE/.tmp-bash
ROOT=$TMPBASE/tree
trap 'rm -rf -- "$TMPBASE"' EXIT

rm -rf -- "$ROOT"
mkdir -p -- "$ROOT"/{alpha,beta,Gamma,delta,"10-ten","2-two",.hidden}
mkdir -p -- "$ROOT/alpha/child"
touch -- "$ROOT/file1" "$ROOT/file2" "$ROOT/alpha/inner.txt"

cd -- "$ROOT" || exit 1
# shellcheck source=../cd-index.bash
source "$REPO/cd-index.bash" || exit 1

pass=0 fail=0
ok()   { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; fail=$((fail+1)); }

expect_pwd() { # 描述 期望目录
  if [[ $PWD == "$2" ]]; then ok "$1"; else bad "$1" "PWD=$PWD 期望=$2"; fi
}
expect_rc() { # 描述 期望退出码 实际退出码
  if (( $3 == $2 )); then ok "$1"; else bad "$1" "rc=$3 期望=$2"; fi
}

echo "== 排序基准（应与 ls 一致）=="
LS_DIRS=()
while IFS= read -r line; do LS_DIRS+=( "$line" ); done \
  < <(ls -d -- */ 2>/dev/null | sed 's:/$::')
printf '  ls 顺序: %s\n' "${LS_DIRS[*]}"

echo "== 1. cd ./N =="
for i in "${!LS_DIRS[@]}"; do
  builtin cd -- "$ROOT"
  cd "./$((i+1))" >/dev/null 2>&1; rc=$?
  expect_pwd "cd ./$((i+1)) -> ${LS_DIRS[i]}" "$ROOT/${LS_DIRS[i]}"
  expect_rc  "cd ./$((i+1)) 退出码" 0 "$rc"
done

echo "== 2. 结尾斜杠 / 前导零 =="
builtin cd -- "$ROOT"; cd ./3/ >/dev/null 2>&1
expect_pwd "cd ./3/ -> ${LS_DIRS[2]}" "$ROOT/${LS_DIRS[2]}"
builtin cd -- "$ROOT"; cd ./03 >/dev/null 2>&1
expect_pwd "cd ./03 -> ${LS_DIRS[2]}" "$ROOT/${LS_DIRS[2]}"

echo "== 3. cd ./0 只列编号 =="
builtin cd -- "$ROOT"
out=$(cd ./0 2>&1); rc=$?
expect_rc  "cd ./0 退出码" 0 "$rc"
expect_pwd "cd ./0 不改变目录" "$ROOT"
if grep -q '1)' <<<"$out" && grep -q "${LS_DIRS[0]}" <<<"$out"; then ok "cd ./0 输出编号列表"; else bad "cd ./0 输出编号列表" "$out"; fi

echo "== 4. 越界 / 无子目录 =="
builtin cd -- "$ROOT"
cd ./999 >/dev/null 2>&1; rc=$?
expect_rc  "cd ./999 退出码=1" 1 "$rc"
expect_pwd "cd ./999 不改变目录" "$ROOT"
mkdir -p -- "$ROOT/alpha/empty"
builtin cd -- "$ROOT/alpha/empty"
cd ./1 >/dev/null 2>&1; rc=$?
expect_rc  "空目录 cd ./1 退出码=1" 1 "$rc"
expect_pwd "空目录 cd ./1 不改变目录" "$ROOT/alpha/empty"

echo "== 5. 隐藏目录默认不计入，CD_INDEX_ALL=1 时计入 =="
builtin cd -- "$ROOT"
n_nodots=$(ls -d -- */ 2>/dev/null | wc -l)
cd ./1 >/dev/null 2>&1
if [[ $PWD != "$ROOT/.hidden" ]]; then ok "默认跳过 .hidden"; else bad "默认跳过 .hidden" "PWD=$PWD"; fi
builtin cd -- "$ROOT"
CD_INDEX_ALL=1 cd ./1 >/dev/null 2>&1
expect_pwd "CD_INDEX_ALL=1 时 .hidden 计入" "$ROOT/.hidden"
unset CD_INDEX_ALL

echo "== 6. 同名真目录优先（不破坏原语义）=="
mkdir -p -- "$ROOT/beta/1/x" "$ROOT/beta/x"
builtin cd -- "$ROOT/beta"
cd ./1 >/dev/null 2>&1
expect_pwd "cd ./1 进入真实目录 beta/1" "$ROOT/beta/1"
cd ./1 >/dev/null 2>&1
expect_pwd "在 beta/1 中 cd ./1 -> x" "$ROOT/beta/1/x"

echo "== 7. 同名普通文件不阻塞序号语义 =="
touch -- "$ROOT/2"
builtin cd -- "$ROOT"
cd ./2 >/dev/null 2>&1
expect_pwd "存在文件 2 时 cd ./2 仍按序号" "$ROOT/${LS_DIRS[1]}"

echo "== 8. 原有 cd 行为原样透传 =="
builtin cd -- "$ROOT"
cd /tmp >/dev/null 2>&1;  expect_pwd "cd /tmp（绝对路径）" "/tmp"
cd "$ROOT" >/dev/null 2>&1; expect_pwd "cd <绝对路径>" "$ROOT"
cd alpha >/dev/null 2>&1;  expect_pwd "cd alpha（无 ./ 前缀）" "$ROOT/alpha"
cd child >/dev/null 2>&1;  expect_pwd "cd child" "$ROOT/alpha/child"
cd .. >/dev/null 2>&1;      expect_pwd "cd .." "$ROOT/alpha"
cd - >/dev/null 2>&1;      expect_pwd "cd -" "$ROOT/alpha/child"
cd - >/dev/null 2>&1;      expect_pwd "cd - 再来一次" "$ROOT/alpha"
cd ~ >/dev/null 2>&1;      expect_pwd "cd ~" "$HOME"
builtin cd -- "$ROOT"
cd /definitely/not/here >/dev/null 2>&1; rc=$?
if (( rc != 0 )); then ok "cd 不存在路径 返回非 0"; else bad "cd 不存在路径 返回非 0" "rc=$rc"; fi
builtin cd -- "$ROOT/alpha/child"
cd >/dev/null 2>&1;        expect_pwd "cd（无参数，回 \$HOME）" "$HOME"
builtin cd -- "$ROOT"
cd . >/dev/null 2>&1;      expect_pwd "cd ." "$ROOT"
cd ./alpha/child >/dev/null 2>&1; expect_pwd "cd ./alpha/child 正常路径" "$ROOT/alpha/child"
builtin cd -- "$ROOT"
cd './alpha' >/dev/null 2>&1;     expect_pwd "cd './alpha'（引号包裹）" "$ROOT/alpha"

echo "== 9. 序号按目录数量，不数文件 =="
printf '  文件数=%s 目录数=%s\n' "$(find "$ROOT" -maxdepth 1 -type f | wc -l)" "$(ls -d -- "$ROOT"/*/ | wc -l)"
builtin cd -- "$ROOT"; cd ./"$n_nodots" >/dev/null 2>&1
expect_pwd "cd ./最后一个序号 可用" "$ROOT/${LS_DIRS[$((n_nodots-1))]}"

echo
printf 'bash: 通过 %d，失败 %d\n' "$pass" "$fail"
exit $(( fail > 0 ))
