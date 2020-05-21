export DISPLAY=:0.0
export JAVA_HOME=$(/usr/libexec/java_home)

##
# Your previous /Users/jlaney/.bash_profile file was backed up as /Users/jlaney/.bash_profile.macports-saved_2010-09-13_at_11:27:47
##

export PATH=~/bin:/usr/local/opt/python@3.8/bin:/usr/local/bin:/usr/local/sbin:$PATH
#export PDSH_SSH_ARGS_APPEND="-q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=publickey"

# alias wf='cd ~/Development/yammer/workfeed'
# alias yamjs='cd ~/Development/yammer/yamjs'
# export WORKFEED_DIR=/Users/jlaney/Development/yammer/workfeed

# for git
alias glog='git log --name-status'
alias glogme='git log --name-status --author=$USER'

# alias yamsh='cd /Users/jlaney/Development/yammer/yamsh'
# alias jssh='ssh -A -t jumphost-001.sjc1.yammer.com ssh $@'
# #alias ssh='ssh -A -t jumphost.int.yammer.com ssh $@'
# alias staging="ssh stageweb-002.sjc1.yammer.com"
# alias staging1="ssh stageweb-001.sjc1.yammer.com"
# alias thunderdome="ssh stageweb-003.sjc1.yammer.com"
# alias pg_stats='psql -h mdb-005.sjc1.yammer.com -U prod wf_production'
# alias pg_prod='psql -h mdb-002.sjc1.yammer.com -U prod wf_production'
# alias psc='ssh web-010.sjc1.yammer.com'
# alias cron1='ssh cron-001.sjc1.yammer.com'
# alias cron2='ssh cron-002.sjc1.yammer.com'
# alias spareworker1='ssh spareworker-001.sjc1.yammer.com'
# alias spareworker2='ssh spareworker-002.sjc1.yammer.com'
# alias worker='ssh worker-001.sjc1.yammer.com'
# alias deploy='ssh deploy-001.sjc1.yammer.com'
# alias londiste='ssh londiste-001.sjc1.yammer.com'
# #alias vagrant='/usr/bin/ssh vagrant@console.yammer.dev'
# alias vg='cd ~/Development/yammer/vagrant'
#for rails
alias ptl="tail -f log/development.log"
alias sc='script/console'


# alias jssh='ssh -At jumphost.dm2.yammer.com ssh -A $@'
alias psx="ps auxw | grep $1"

function tab {
  # Usage: tab name [command]
  local name=$1
  local cmd=$2
  local tabdir=$HOME/Library/tabs
  local file=$tabdir/$name
  mkdir -p $tabdir
  rm -f $file

  if [ "$cmd" = '' ]; then
    # No command specified, just rename tab.
    # This idea for this came from: http://pseudogreen.org/blog/set_tab_names_in_leopard_terminal.html
    ln `which sleep` $file
    $file 5 &
    local tabpid=$(jobs -x echo %+)
    disown %+
    kill -STOP $tabpid
  else
    # Rename tab and execute command.
    shift 2
    ln `which $cmd` $file
    $file $@
  fi
  rm -f $file
}

function parse_gb {
  cut -c17- .git/HEAD 2> /dev/null
}
PS1="\W \[\033[01;33m\]\$(parse_gb)\[\033[00;37m\]$ "

if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi
