# cd-index

用「序号」进入当前目录下的第 N 个文件夹 —— 把 `ls` 的输出当数组下标用。

```console
$ ls
alpha  beta  Gamma  delta  docs  src
$ cd ./4          # 等价于 cd ./delta
```

[![CI](https://github.com/FockHatree/cd-index/actions/workflows/ci.yml/badge.svg)](https://github.com/FockHatree/cd-index/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![shell](https://img.shields.io/badge/shell-bash%20%7C%20zsh-blue)

## 它解决什么

目录里有一堆名字很长的子目录时，`cd` 需要复制粘贴整串名字。这个工具让你直接按
`ls` 里看到的顺序说「第几个」，并且**不改变 `cd` 的其它任何行为**。

## 用法

| 命令 | 效果 |
| --- | --- |
| `cd ./3` | 进入第 3 个文件夹，等价 `cd ./'第3个文件夹的名字'` |
| `cd ./3/` | 同上，允许结尾斜杠；`cd ./03` 前导零也无副作用 |
| `cd ./0` | 不跳转，只打印 `编号 -> 文件夹名` 对照表 |
| `CD_INDEX_ALL=1 cd ./1` | 这一次把隐藏目录（`.git` 等）也算进编号 |
| `cd ./999` | 超出范围：打印对照表、返回 1、**不改变当前目录** |

## 规则

| 行为 | 说明 |
| --- | --- |
| 计数的对象 | **只数目录，不数文件**（所以 `N` 个文件夹与 `m` 个文件互不干扰） |
| 排序 | 与 `ls` 完全一致：当前 locale 的字典序（例如 `10-ten` 排在 `2-two` 之前） |
| 隐藏目录 | 默认不计入；`CD_INDEX_ALL=1` 时计入 |
| 同名真目录 | 若当前目录下真存在名为 `3` 的目录，`cd ./3` 仍进入它（不破坏原语义） |
| 同名普通文件 | 存在名为 `2` 的**文件**时，`cd ./2` 按序号处理（否则这条命令只会报错） |

其它一切用法都逐字透传给内置 `cd`：`cd`、`cd -`、`cd ..`、`cd .`、`cd /tmp`、
`cd ~/x`、`cd alpha`、`cd ./alpha/child`。

## 安装

### 方式 1：install.sh（推荐）

```bash
git clone https://github.com/FockHatree/cd-index ~/.local/share/cd-index
cd ~/.local/share/cd-index
./install.sh              # 幂等；--dry-run 可先看要做什么
./install.sh --uninstall  # 卸载
```

脚本做的事：在 `~/.bashrc` 里写入一段带标记的托管块；若检测到 oh-my-zsh，则把
`$ZSH_CUSTOM/cd-index.zsh` 软链到本仓库的 `cd-index.plugin.zsh`（oh-my-zsh 会自动
加载 `$ZSH_CUSTOM/*.zsh`，无需改 `.zshrc`）。重复执行只会更新那段托管内容，并会顺手
清掉历史遗留的手工 `source` 行。

### 方式 2：作为 oh-my-zsh 插件

```bash
git clone https://github.com/FockHatree/cd-index ~/.oh-my-zsh/custom/plugins/cd-index
# 然后在 ~/.zshrc 里把 cd-index 加进 plugins=(...)
```

### 方式 3：完全手动

```bash
echo 'source /path/to/cd-index/cd-index.bash' >> ~/.bashrc   # bash
echo 'source /path/to/cd-index/cd-index.zsh'  >> ~/.zshrc    # zsh
```

## 环境变量

| 变量 | 默认 | 作用 |
| --- | --- | --- |
| `CD_INDEX_ALL` | 未设置 | 设为 `1` 时隐藏目录参与编号 |

## 原理与取舍

实现只是给 shell 定义一个名叫 `cd` 的**函数**：只拦截形如 `./<纯数字>` 的单参数，
其余情况一律 `builtin cd "$@"`。代价有两点：

1. 该 shell 里 `cd` 变成函数（`type cd` 会显示函数）。不影响脚本，因为脚本里几乎不会
   出现 `cd ./<数字>` 这种写法。已确认 oh-my-zsh 自身不定义 `cd`，且本函数在其之后加载，
   `cd one`、`cd ..`、TAB 补全都照常。
2. 工程里真有名为数字的目录时，那个位置不能用序号进入（见上表「同名真目录」）。

仓库可任意移动/改名：`cd-index.plugin.zsh` 用 zsh 的 `${(%):-%x}` 自定位，
`install.sh` 每次都按自身实际路径重写托管块。

## 开发

```bash
make test     # bash + zsh 两套自测
make check    # bash -n / zsh -n 语法检查
make lint     # shellcheck（需自行安装）
./install.sh --dry-run
```

| 文件 | 说明 |
| --- | --- |
| `cd-index.bash` | bash 实现 |
| `cd-index.zsh` | zsh 实现 |
| `cd-index.plugin.zsh` | oh-my-zsh / zinit 插件入口 |
| `install.sh` | 幂等安装 / 卸载 |
| `test/run.sh` | 统一测试入口（`test/bash.sh` + `test/zsh.zsh`） |
| `Makefile` | 常用任务 |

测试的期望值全部从 `ls` **现算**而不是硬编码顺序，所以换 locale 也不会误报。

### 已验证环境

- Linux（Ubuntu），bash 5.3.9 + zsh 5.9
- 真实 oh-my-zsh 环境（powerlevel10k + `git` `zsh-autosuggestions`
  `zsh-syntax-highlighting` `z` `extract` `web-search`）下交互式实测通过
- 断言数：bash 40 项、zsh 40 项，全部通过

### 未验证 / 已知限制

- macOS 自带 bash 3.2 未实测（函数体只用 Bash 3.2 就有的特性，测试脚本也已去掉
  `mapfile`，但没人真跑过）。欢迎在 macOS 上跑 `make test` 反馈。
- 仅支持 bash / zsh；fish、PowerShell 不适用（fish 里 `cd ./3` 语法也不同）。

## 维护者备忘

- 发布新版本：更新 `CHANGELOG.md` → `make test` 全绿 → 打 tag 推送：
  `git tag -a vX.Y.Z -m "cd-index vX.Y.Z" && git push origin vX.Y.Z`
- 若仓库改名或迁移，记得同步 README 里的徽章 URL 与 `git clone` 地址
- 改动 `install.sh` 的托管块标记时，注意与历史版本写入的标记保持兼容，否则老用户
  重跑安装会残留重复的 `source` 行

## License

[MIT](LICENSE)
