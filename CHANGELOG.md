# 更新日志

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与
[语义化版本](https://semver.org/lang/zh-CN/)。

## [未发布]

## [0.1.0] - 2026-09-28

### 新增

- bash 实现 `cd-index.bash`：`cd ./N` 进入当前目录下第 N 个文件夹
- zsh 实现 `cd-index.zsh`：同样的语义，用 `*(N/)` / `*(ND/)` 限定符取目录
- `cd ./0` 打印 `编号 -> 文件夹名` 对照表；序号越界时报错、返回 1 且不改变当前目录
- `CD_INDEX_ALL=1` 让隐藏目录参与编号
- 同名真目录优先，保证不破坏 `cd ./3` 的原有含义
- oh-my-zsh 插件入口 `cd-index.plugin.zsh`，用 `${(%):-%x}` 自定位，仓库可任意移动
- `install.sh`：幂等安装 / 卸载（`--dry-run`、`--bash-only`、`--zsh-only`），
  自动清理历史遗留的手工 `source` 行
- 自测：bash 40 项断言、zsh 40 项断言，`make test` 一键运行；期望值全部从 `ls` 现算
- GitHub Actions：`bash -n` / `zsh -n` 语法检查 + shellcheck + 双 shell 测试
- README、LICENSE(MIT)、Makefile、`.editorconfig`

### 修复

- CI 的 `make lint`（shellcheck 0.9）报错导致流水线失败：
  - `cd-index.bash`：`builtin cd` 加 `|| return`（不能 `|| exit`，否则会杀掉用户的 shell），消除 SC2164
  - `install.sh`：提示语里的 `$SHELL` 改为双引号转义，消除 SC2016
  - `test/bash.sh`：`cd` 本身就是被测对象，对 SC2164/SC2012/SC2103 加显式 disable 并注明理由；
    目录计数由 `ls -d */ | wc -l` 改为 `find`（排除隐藏目录，与 `*/` 语义一致）
  - `Makefile`：lint 目标加 `-x -P .`，修正 SC1091（`source=` 路径按仓库根解析）
- 更正文档中的断言数：bash 套件为 40 项（此前误写 39）
