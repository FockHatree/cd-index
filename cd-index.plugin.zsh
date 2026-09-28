# cd-index.plugin.zsh —— oh-my-zsh / zinit / antigen 等框架的插件入口
#
# 文件名遵循「<插件名>.plugin.zsh」约定，因此可以这样安装：
#
#   git clone https://github.com/FockHatree/cd-index ~/.oh-my-zsh/custom/plugins/cd-index
#   # 然后写进 ~/.zshrc:  plugins=(... cd-index)
#
# ${(%):-%x} 是 zsh 里「当前正在被解析的文件路径」的写法，
# 所以本文件所在目录能自动确定，整个仓库可以任意移动、改名或软链。

source "${${(%):-%x}:A:h}/cd-index.zsh"
