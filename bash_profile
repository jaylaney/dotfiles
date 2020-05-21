export DISPLAY=:0.0
export JAVA_HOME=$(/usr/libexec/java_home)

export PATH=~/bin:/usr/local/opt/python@3.8/bin:/usr/local/bin:/usr/local/sbin:$PATH

alias glog='git log --name-status'
alias glogme='git log --name-status --author=$USER'

#for rails
alias ptl="tail -f log/development.log"
alias sc='script/console'

# alias jssh='ssh -At jumphost.dm2.yammer.com ssh -A $@'
alias psx="ps auxw | grep $1"

function parse_gb {
  cut -c17- .git/HEAD 2> /dev/null
}
PS1="\W \[\033[01;33m\]\$(parse_gb)\[\033[00;37m\]$ "

if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi
