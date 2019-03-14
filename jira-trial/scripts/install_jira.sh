#!/bin/bash
# 2018 j.peschke@syseleven.de


# wait for a valid network configuration
until ping -c 1 syseleven.de; do sleep 5; done

# install necessary services
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" pwgen haveged unzip wget jq git mysql-server tomcat8 letsencrypt s3cmd nginx


# creating a database
rootpass=$(pwgen 16 1)
customerpass=$(pwgen 16 1)
/usr/bin/mysqladmin -u root password "$rootpass"

cat <<EOF> /root/.my.cnf
[client]
user = root
password = ${rootpass} 
host = localhost
EOF

cat <<EOF> /root/createDB.sql
CREATE DATABASE syseleven;
CREATE USER 'syseleven'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON syseleven.* TO 'syseleven'@'localhost';
FLUSH PRIVILEGES;
EOF

sed -i "s/password/${customerpass}/g" /root/createDB.sql
mysql < /root/createDB.sql

cat <<EOF> /home/syseleven/dbcredentials

DB-Name: syseleven
DB-User: syseleven
DB-Server: localhost
DB-Password: ${customerpass}

EOF

chmod 400 /home/syseleven/dbcredentials
chown syseleven: /home/syseleven/dbcredentials

echo "finished generic mysql setup"

echo "starting to download jira..."

cd /root

# disable generic tomcat
systemctl stop tomcat8
systemctl disable tomcat8


wget -O atlassian-jira-software-7.10.2-x64.bin https://product-downloads.atlassian.com/software/jira/downloads/atlassian-jira-software-7.10.2-x64.bin?_ga=2.262852751.261143986.1530542898-1020777733.1474373437 -O /root/atlassian-jira-software-7.10.2-x64.bin

# https://community.atlassian.com/t5/Jira-questions/Cannot-connect-MySQL-database-to-Jira/qaq-p/789897
# get java mysql connector:
## wget https://cdn.mysql.com//Downloads/Connector-J/mysql-connector-java_8.0.11-1ubuntu16.04_all.deb
##dpkg -i mysql-connector-java_8.0.11-1ubuntu16.04_all.deb
wget https://cdn.mysql.com//Downloads/Connector-J/mysql-connector-java-5.1.46.tar.gz
tar -xzvf mysql-connector-java-5.1.46.tar.gz

echo "starting jira..."

chmod 700 atlassian-jira-software-7.10.2-x64.bin
/root/atlassian-jira-software-7.10.2-x64.bin -q -varfile /root/response.varfile

mkdir -p /etc/letsencrypt/renewal
cp letsencrypt_renewalconfig /etc/letsencrypt/renewal/cloudstackers.de.conf

# check if we have a valid tls setup. If yes, we can use it in gnixn config
if test -f /etc/letsencrypt/live/cloudstackers.de/fullchain.pem; then
  cp /root/nginx_defaultconfig_ssl /etc/nginx/sites-enabled/default
  nginx -T && systemctl restart nginx
else
  cp /root/nginx_defaultconfig /etc/nginx/sites-enabled/default
  nginx -T && systemctl restart nginx
fi

# some hacks around jira, java and mysql
# (yes, jira does only work with init.d as of july, 26 2018 )
## cp /usr/share/java/mysql-connector-java-8.0.11.jar /opt/atlassian/jira/atlassian-jira/WEB-INF/lib/
cp mysql-connector-java-5.1.46/mysql-connector-java-5.1.46.jar /opt/atlassian/jira/lib/
/etc/init.d/jira stop
/etc/init.d/jira start

# let's create a db backup in the morning:
systemd-run --on-calendar="*-*-* 4:00:00" /usr/local/sbin/createDbBackup
