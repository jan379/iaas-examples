#!/bin/bash
# 2016 j.peschke@innovo-cloud.de

# wait for a valid network configuration
echo "# Waiting for valid network configuration"
until ping -c 1 innovo-cloud.de; do sleep 1; done

echo "# Install dependencies"
export DEBIAN_FRONTEND=noninteractive
apt install -y wget openjdk-8-jre
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
##echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" > /etc/apt/sources.list.d/elasticsearch.list
echo "deb https://artifacts.elastic.co/packages/oss-7.x/apt stable main" > /etc/apt/sources.list.d/elasticsearch.list
apt update
apt install -y elasticsearch-oss

## echo "JAVA_HOME=/usr/bin/java" >> /etc/default/elasticsearch
echo "network.host: 0.0.0.0" >> /etc/elasticsearch/elasticsearch.yml
echo "cluster.name: innovo-elk" >> /etc/elasticsearch/elasticsearch.yml
echo 'discovery.zen.ping.unicast.hosts: ["elasticsearch0.node.consul", "elasticsearch1.node.consul", "elasticsearch2.node.consul"]' >> /etc/elasticsearch/elasticsearch.yml
echo 'cluster.initial_master_nodes: ["elasticsearch0", "elasticsearch1", "elasticsearch2"]' >> /etc/elasticsearch/elasticsearch.yml
systemctl restart elasticsearch

# implement consul health check
cat <<EOF> /etc/consul.d/elasticsearch_health.json
{
  "service": {
    "name": "elasticsearch",
    "port": 80,
    "tags": ["elasticsearch", "nosql"],
    "check": {
      "id": "elasticsearch",
      "name": "elasticsearch-availability",
      "http": "http://localhost:9200",
      "interval": "10s"
    }
  }
}
EOF

systemctl restart consul 

echo "# Finished elasticsearch installation"
