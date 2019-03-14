#!/bin/bash
# 2019 j.peschke@syseleven.de


# wait for a valid network configuration
until ping -c 1 syseleven.de; do sleep 5; done

wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

cat <<EOF> /etc/apt/sources.list.d/elasticsearch.list
deb https://artifacts.elastic.co/packages/6.x/apt stable main
EOF


# install necessary services
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" openjdk-8-jre jq 
apt-get install -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" elasticsearch 

systemctl restart elasticsearch
