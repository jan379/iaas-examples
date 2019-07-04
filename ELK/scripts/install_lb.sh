#!/bin/bash
# 2015 j.peschke@innovo-cloud.de

# wait for a valid network configuration
echo "# Waiting for valid network configuration"
until ping -c 1 innovo-cloud.de; do sleep 1; done

# get internal ipv4 ip
internalIP=$(curl -s 169.254.169.254/latest/meta-data/local-ipv4)

echo "# Install dependencies"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" nginx

# implement service check to announce consul ui

cat <<EOF> /etc/consul.d/consul-ui.json
{
  "service": {
    "name": "consul-ui",
    "tags": ["consul", "webui"],
    "check": {
      "id": "consul-ui-check",
      "name": "consul-ui-check",
      "http": "http://localhost:8500/ui",
      "interval": "10s"
    }
  }
}
EOF

cat <<EOF> /etc/consul.d/kibana.json
{
  "service": {
    "name": "kibana",
    "tags": ["kibana", "webui"],
    "check": {
      "id": "kibana-check",
      "name": "kibana-check",
      "http": "http://localhost:5601",
      "interval": "10s"
    }
  }
}
EOF


systemctl restart consul 

# generate a upstream-template used by consul-template
cat <<EOF> /opt/consul-http-upstreams.ctpl
upstream innovo-elasticsearch  {
  least_conn;
  {{range service "elasticsearch"}}server {{.Address}}:9200 max_fails=3 fail_timeout=60 weight=1;
  {{else}}server 127.0.0.1:65535; # force a 502{{end}}
}
upstream innovo-consul-ui  {
  least_conn;
  {{range service "consul-ui"}}server {{.Address}}:8500 max_fails=3 fail_timeout=60 weight=1;
  {{else}}server 127.0.0.1:65535; # force a 502{{end}}
}

upstream innovo-kibana  {
  least_conn;
  {{range service "kibana"}}server {{.Address}}:5601 max_fails=3 fail_timeout=60 weight=1;
  {{else}}server 127.0.0.1:65535; # force a 502{{end}}
}
 
EOF

# configure and run consul-template for nginx:

cat <<EOF> /etc/systemd/system/consultemplate-upstreams.service
[Unit]
Description=consul-template for nginx upstreams
Requires=network-online.target
After=network-online.target

[Service]
User=root
EnvironmentFile=-/etc/default/consul-template
Environment=GOMAXPROCS=2
Restart=on-failure
ExecStart=/usr/local/sbin/consul-template -template "/opt/consul-http-upstreams.ctpl:/etc/nginx/upstream.conf:service nginx restart"
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF

systemctl enable consultemplate-upstreams
systemctl restart consultemplate-upstreams

# create a default nginx vhost
cat <<EOF> /etc/nginx/sites-enabled/default
    server {
        listen          9200 default_server;
        server_name     _;
        access_log	/var/log/nginx/elasticsearch.log proxy;

        error_page 502 /errorpage.html;
        location = /errorpage.html {
            root  /var/www/;
        }

        location        / {
            proxy_pass      http://innovo-elasticsearch;
        }
    }
    server {
        listen          8080 default_server;
        server_name     _;
        access_log	/var/log/nginx/consului.log proxy;

        error_page 502 /errorpage.html;
        location = /errorpage.html {
            root  /var/www/;
        }

        location        / {
            proxy_pass      http://innovo-consul-ui;
        }
    }
    server {
        listen          80 default_server;
        server_name     _;
        access_log	/var/log/nginx/kibana.log proxy;

        error_page 502 /errorpage.html;
        location = /errorpage.html {
            root  /var/www/;
        }

        location        / {
            proxy_pass      http://innovo-kibana;
        }
    }
EOF

# configure core nginx 
cat <<EOF> /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    log_format proxy '[\$time_local] Cache: \$upstream_cache_status '
                     '\$upstream_addr \$upstream_response_time \$status '
                     '\$bytes_sent \$proxy_add_x_forwarded_for \$request_uri';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    include /etc/nginx/upstream.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

systemctl restart nginx

# install kibana
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
##echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" > /etc/apt/sources.list.d/elasticsearch.list
echo "deb https://artifacts.elastic.co/packages/oss-7.x/apt stable main" > /etc/apt/sources.list.d/elasticsearch.list
apt-get update
apt-get install -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" kibana-oss
echo 'server.host: "0.0.0.0"' >> /etc/kibana/kibana.yml
echo 'elasticsearch.hosts: "http://elasticsearch0.node.consul:9200"' >> /etc/kibana/kibana.yml
systemctl enable kibana
systemctl restart kibana


logger "# Finished lbserver installation"
echo "# Finished lbserver installation"



