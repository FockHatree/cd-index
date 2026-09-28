# cd-index —— 常用开发任务
SHELL := /bin/bash
.PHONY: help test test-bash test-zsh check lint install uninstall

help:            ## 显示可用目标
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | sed 's/:.*## /  -- /'

test: test-bash test-zsh  ## 跑全部测试（bash + zsh）

test-bash:       ## 只跑 bash 套件
	bash test/bash.sh

test-zsh:        ## 只跑 zsh 套件
	zsh test/zsh.zsh

check:           ## 语法检查（不需要额外依赖）
	@for f in cd-index.bash install.sh test/run.sh test/bash.sh; do \
		bash -n "$$f" && echo "ok  bash -n $$f"; \
	done
	@for f in cd-index.zsh cd-index.plugin.zsh test/zsh.zsh; do \
		zsh -n "$$f" && echo "ok  zsh -n $$f"; \
	done

lint:            ## shellcheck 静态检查（需自行安装 shellcheck）
	shellcheck cd-index.bash install.sh test/run.sh test/bash.sh

install:         ## 安装到 ~/.bashrc 与 oh-my-zsh
	./install.sh

uninstall:       ## 卸载
	./install.sh --uninstall
