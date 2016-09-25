#!/bin/bash
set -eux


#
# configure APT.

echo 'Defaults env_keep += "DEBIAN_FRONTEND"' >/etc/sudoers.d/env_keep_apt
chmod 440 /etc/sudoers.d/env_keep_apt
export DEBIAN_FRONTEND=noninteractive


#
# trust the proxy ca.

cp /vagrant/tmp/squid-cache-ca.pem /usr/local/share/ca-certificates/squid-cache-ca.crt
update-ca-certificates


#
# configure the proxy system-wise.

cat >/etc/profile.d/proxy.sh <<'EOF'
export http_proxy=http://proxy.example.com:3128
export https_proxy=$http_proxy
EOF

source /etc/profile.d/proxy.sh


#
# make sure the package index cache is up-to-date before installing anything.

apt-get update


#
# install vim.

apt-get install -y --no-install-recommends vim

cat >~/.vimrc <<'EOF'
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
EOF


#
# configure the shell.

cat >~/.bash_history <<'EOF'
source /etc/profile.d/proxy.sh 
EOF

cat >~/.bashrc <<'EOF'
# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

export EDITOR=vim
export PAGER=less

alias l='ls -lF --color'
alias ll='l -a'
alias h='history 25'
alias j='jobs -l'
EOF

cat >~/.inputrc <<'EOF'
"\e[A": history-search-backward
"\e[B": history-search-forward
"\eOD": backward-word
"\eOC": forward-word
set show-all-if-ambiguous on
set completion-ignore-case on
EOF


#
# test with wget.

apt-get install -y jq
[ -n "$(wget -qO- http://httpbin.org/ip | jq -r .origin)" ]
[ -n "$(wget -qO- https://httpbin.org/ip | jq -r .origin)" ]


#
# test with python.

cat >main.py <<'EOF'
import sys
from urllib import request

request.urlopen(sys.argv[1]).read()
EOF
python3 main.py http://httpbin.org/ip
python3 main.py https://httpbin.org/ip


#
# test with java.
# NB java does not use the http(s)_proxy environment variables.
# see http://docs.oracle.com/javase/8/docs/technotes/guides/net/proxies.html

apt-get install -y default-jdk
cat >Main.java <<'EOF'
import java.net.URL;

class Main {
    public static void main(String[] args) throws Exception {
        new URL(args[0])
            .openConnection()
            .getInputStream()
            .close();
    }
}
EOF
javac Main.java
JAVA_OPTS=""
JAVA_OPTS="$JAVA_OPTS -Dhttp.proxyHost=proxy.example.com"
JAVA_OPTS="$JAVA_OPTS -Dhttp.proxyPort=3128"
JAVA_OPTS="$JAVA_OPTS -Dhttps.proxyHost=proxy.example.com"
JAVA_OPTS="$JAVA_OPTS -Dhttps.proxyPort=3128"
java $JAVA_OPTS Main http://httpbin.org/ip
java $JAVA_OPTS Main https://httpbin.org/ip
