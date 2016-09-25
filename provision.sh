#!/bin/bash
set -eux

domain=$(hostname --fqdn)


echo 'Defaults env_keep += "DEBIAN_FRONTEND"' >/etc/sudoers.d/env_keep_apt
chmod 440 /etc/sudoers.d/env_keep_apt
export DEBIAN_FRONTEND=noninteractive


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
systemctl status squid
systemctl restart squid
journalctl -u squid -f
tail -f /var/log/squid/access.log
tail -f /var/log/squid/store.log
cat /etc/squid/squid.conf | grep -v '^\s*#' | grep .
vim /etc/squid/squid.conf
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
# build from source (because the squid package does not come with ssl support).

sed -i -E 's,^# (deb-src .+),\1,' /etc/apt/sources.list
sed -i -E 's,^(deb-src .+ partner),# \1,' /etc/apt/sources.list
apt-get update
apt-get install -y dpkg-dev
mkdir squid-source
pushd squid-source
apt-get source squid
apt-get build-dep -y squid
apt-get install -y libssl-dev ssl-cert squid-langpack
cd squid3*
sed -i -E 's,(.+)(--datadir=.+),\1--with-openssl --enable-ssl-crtd \\\n\1\2,' debian/rules
dpkg-buildpackage -rfakeroot -uc -b
dpkg -i ../{squid-common,squid_,squidclient_}*.deb
popd


#
# create the Squid CA certificate.  It will be used to sign the (fake) certificates
# that the proxy clients see when they connect to a https site.
# see http://wiki.squid-cache.org/Features/DynamicSslCert

install -d -o proxy -g proxy -m 700 /etc/squid/ssl_cert
openssl \
    req \
    -new \
    -newkey \
    rsa:2048 \
    -sha256 \
    -subj '/CN=Squid Proxying Cache' \
    -days $(python -c 'print(5*365)') \
    -nodes -x509 \
    -extensions v3_ca \
    -keyout /etc/squid/ssl_cert/ca.key \
    -out /etc/squid/ssl_cert/ca.pem
chown -R proxy:proxy /etc/squid/ssl_cert
chmod 400 /etc/squid/ssl_cert/ca.key
/usr/lib/squid/ssl_crtd -c -s /var/lib/ssl_db
find /var/lib/ssl_db -type d -exec chmod 700 {} \;
chown -R proxy:proxy /var/lib/ssl_db


#
# configure squid.
# see https://help.ubuntu.com/community/Squid
# see http://wiki.squid-cache.org/SquidFaq
# see http://wiki.squid-cache.org/SquidFaq/SquidLogs
# see http://wiki.squid-cache.org/Features/DynamicSslCert
# see http://wiki.squid-cache.org/ConfigExamples/Intercept/SslBumpExplicit

cp /etc/squid/squid.conf /etc/squid/squid.conf.orig
cat >/etc/squid/squid.conf <<'EOF'
acl localnet src 10.0.0.0/8
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
acl CONNECT method CONNECT
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localnet
http_access allow localhost
http_access deny all

http_port \
    3128 \
    ssl-bump \
    generate-host-certificates=on \
    dynamic_cert_mem_cache_size=16MB \
    key=/etc/squid/ssl_cert/ca.key \
    cert=/etc/squid/ssl_cert/ca.pem

ssl_bump bump all

sslcrtd_program \
    /usr/lib/squid/ssl_crtd \
    -s /var/lib/ssl_db \
    -M 16MB \
    -b 4096 \
    sslcrtd_children 5

# ~15 GiB cache.
cache_dir ufs /var/spool/squid 15000 16 256

maximum_object_size 200 MB

cache_store_log daemon:/var/log/squid/store.log

shutdown_lifetime 2 seconds

coredump_dir /var/spool/squid

# refresh_pattern [-i] regex min percent max [options]
#refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
refresh_pattern (\.deb|\.udeb)$ 129600 100% 129600
refresh_pattern (\.exe|\.nupkg)$ 129600 100% 129600
refresh_pattern -i \.(gif|png|jpg|jpeg|ico)$ 3600 90% 43200
refresh_pattern . 0 20% 4320
EOF

systemctl restart squid


# copy the CA certificate to the host (to be used on other machines).
mkdir -p /vagrant/tmp
cp -f /etc/squid/ssl_cert/ca.pem /vagrant/tmp/squid-cache-ca.pem
openssl x509 -in /etc/squid/ssl_cert/ca.pem -outform der -out /vagrant/tmp/squid-cache-ca.der


# show the configuration.
#cat /etc/squid/squid.conf | grep -v '^\s*#' | grep .

# show the squid version.
squid -v


#
# test.

apt-get install -y jq
[ -n "$(http_proxy=localhost:3128 wget -qO- http://httpbin.org/ip | jq -r .origin)" ]
[ -n "$(https_proxy=localhost:3128 wget -qO- --ca-certificate=/etc/squid/ssl_cert/ca.pem https://httpbin.org/ip | jq -r .origin)" ]
