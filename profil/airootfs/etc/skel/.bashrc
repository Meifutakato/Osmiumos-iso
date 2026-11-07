[[ $- != *i* ]] && return
alias ls='ls --color=auto'
PS1='\[\e[1;35m\]\u@osmiumos\[\e[0m\] \w \$ '
