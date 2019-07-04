#!/bin/bash
# 2019 jan.peschke@innovo-cloud.de

# wait for a valid network configuration
echo "# Waiting for valid network configuration"
until ping -c 1 innovo-cloud.de; do sleep 5; done

echo "# Install dependencies"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" curl haveged unzip wget jq git dnsmasq dnsutils uuid-runtime

# add a user for consul
echo "# Add consul user"
adduser --quiet --shell /bin/sh --no-create-home --disabled-password --disabled-login --home /var/lib/misc --gecos "Consul system user" consul 

# consul software version
consulversion=1.5.2
consultemplateversion=0.20.0

# install consul
echo "# Download and install consul ${consulversion}"
wget https://releases.hashicorp.com/consul/${consulversion}/consul_${consulversion}_linux_amd64.zip
unzip consul_${consulversion}_linux_amd64.zip
mv consul /usr/local/sbin/
rm consul_${consulversion}_linux_amd64.zip
mkdir -p /etc/consul.d

# install consul template
echo "# Download and install consul-template ${consultemplateversion}"
wget https://releases.hashicorp.com/consul-template/${consultemplateversion}/consul-template_${consultemplateversion}_linux_amd64.zip
unzip consul-template_${consultemplateversion}_linux_amd64.zip
mv consul-template /usr/local/sbin/
rm consul-template_${consultemplateversion}_linux_amd64.zip

# select three defined nodes as server, any other host will be in consul agent mode
if [ "$(hostname -s)" == "elasticsearch0" ] || [ "$(hostname -s)" == "elasticsearch1" ] ; then 
cat <<EOF> /etc/consul.d/consul.json
{
  "datacenter": "fra",
  "data_dir": "/tmp/consul",
  "bootstrap_expect": 3,
  "server": true,
  "enable_script_checks": true,
  "disable_remote_exec": true,
  "retry_join": ["192.168.2.5"]
}
EOF

elif [ "$(hostname -s)" == "lb0" ]; then

cat <<EOF> /etc/consul.d/consul.json
{
  "datacenter": "fra",
  "data_dir": "/tmp/consul",
  "server": true,
  "enable_script_checks": true,
  "disable_remote_exec": true,
  "ui": true,
  "retry_join": ["192.168.2.5"],
  "addresses" : {
    "http": "192.168.2.5 127.0.0.1" 
  }
}
EOF

else 
cat <<EOF> /etc/consul.d/consul.json
{
  "datacenter": "fra",
  "data_dir": "/tmp/consul",
  "server": false,
  "enable_script_checks": true,
  "disable_remote_exec": true,
  "retry_join": ["192.168.2.5"]
}
EOF

fi

cat <<EOF> /etc/systemd/system/consul.service
[Unit]
Description=consul agent
Requires=network-online.target
After=network-online.target

[Service]
User=consul
EnvironmentFile=-/etc/default/consul
Environment=GOMAXPROCS=2
Restart=on-failure
RestartSec=5
StartLimitInterval=0
ExecStart=/usr/local/sbin/consul agent \$OPTIONS -config-dir=/etc/consul.d
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF

systemctl enable consul
systemctl restart consul

# setup dnsmasq to communicate via consul
echo "server=/consul./127.0.0.1#8600" > /etc/dnsmasq.d/10-consul
echo "server=127.0.0.53" >> /etc/dnsmasq.d/10-consul
sed -i "s/127.0.0.53/127.0.0.1/g" /etc/resolv.conf
systemctl restart dnsmasq

logger "# Finished generic core setup"
echo "# Finished generic core setup"
