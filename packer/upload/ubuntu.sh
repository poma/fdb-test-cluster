#!/bin/bash
set -e
set -x

# from http://unix.stackexchange.com/a/28793
# if we aren't root - elevate. This is useful for AMI
if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

export DEBIAN_FRONTEND=noninteractive

# set timezone to UTC
dpkg-reconfigure tzdata

# https://groups.google.com/forum/#!msg/foundationdb-user/BtJf-1Mlx4I/fxXZClLpnOUJ
# sources: https://github.com/ripple/docker-fdb-server/blob/master/Dockerfile
# https://hub.docker.com/r/arypurnomoz/fdb-server/~/dockerfile/

# linux-aws - https://forums.aws.amazon.com/thread.jspa?messageID=769521&tstart=0

# need to clean since images could have stale metadata
apt-get clean && apt-get update
apt-get install -y -qq python lsb linux-aws mosh sysstat iftop build-essential libssl-dev git curl wget htop screen ne

# fix policies (applies to docker)
mv policy-rc.d /usr/sbin

######### FDB

cd /tmp

# download the dependencies
wget https://www.foundationdb.org/downloads/5.1.7/ubuntu/installers/foundationdb-clients_5.1.7-1_amd64.deb
wget https://www.foundationdb.org/downloads/5.1.7/ubuntu/installers/foundationdb-server_5.1.7-1_amd64.deb

# server depends on the client packages
dpkg -i foundationdb-clients_5.1.7-1_amd64.deb
dpkg -i  foundationdb-server_5.1.7-1_amd64.deb

# stop the service
service foundationdb stop

#chown -R foundationdb:foundationdb /etc/foundationdb

# peeked from here
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*
