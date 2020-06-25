#!/bin/bash
#
# cloud init script for full ELK 7.8 on centos 7
# TODO:
#	- Convert this script to work on ubuntu
#	- yum => apt, rpm => .deb
# Consider: Breaking each up into functions
MSG="FAIL LINE"
LOG=/var/log/user_data.sh.log
yum -y update 2>&1 >> $LOG || echo "$MSG 1" >> $LOG
#yum -y install curl epel-release java-11-openjdk.x86_64 nginx rpm unzip wget zip 2>&1 >> $LOG || echo "$MSG 2" >> $LOG
yum -y install curl epel-release java-1.8.0-openjdk.x86_64 nginx pwgen rpm unzip wget zip 2>&1 >> $LOG || echo "$MSG 2" >> $LOG
yum -y install nginx >> $LOG || echo "$MSG 2" >> $LOG
sleep 2 && 
wget -O /dev/shm/elasticsearch-7.8.0-x86_64.rpm https://github.com/dukeofdisaster/elastic-rpms/releases/download/v1/elasticsearch-7.8.0-x86_64.rpm || echo "$MSG 3" >> $LOG
sleep 4 && rpm -ivh /dev/shm/elasticsearch-7.8.0-x86_64.rpm >> $LOG || echo "$MSG 4" >> $LOG
wget -O /dev/shm/logstash-7.8.0.rpm https://github.com/dukeofdisaster/elastic-rpms/releases/download/v1/logstash-7.8.0.rpm >> $LOG || echo "$MSG 5" >> $LOG
rpm -ivh /dev/shm/logstash-7.8.0.rpm 2>&1 >> $LOG || echo "$MSG 6" >> $LOG
#wget -O /dev/shm/filebeat-7.6.2-amd64.deb https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.6.2-amd64.deb || echo "$MSG 7" >> $LOG
wget -O /dev/shm/filebeat-7.8.0-x86_64.rpm https://github.com/dukeofdisaster/elastic-rpms/releases/download/v1/filebeat-7.8.0-x86_64.rpm || echo "$MSG 8" >> $LOG
sleep 2 && rpm -ivh /dev/shm/filebeat-7.8.0-x86_64.rpm  2>&1 >> $LOG || echo "$MSG 9" >> $LOG
wget -O /dev/shm/kibana-7.8.0-x86_64.rpm https://github.com/dukeofdisaster/elastic-rpms/releases/download/v1/kibana-7.8.0-x86_64.rpm || echo "$MSG 10" >> $LOG
sleep 2 && rpm -ivh /dev/shm/kibana-7.8.0-x86_64.rpm || echo "$MSG 11" >> $LOG
cp /etc/hosts /etc/hosts.bak || echo "$MSG 12" >> $LOG
sed -i "s/localhost /localhost logstash1\.local kibana\.local/g" /etc/hosts || echo "$MSG 13" >> $LOG
touch /dev/shm/nodes.yml || echo "$MSG 14" >> $LOG
echo "instances:" >> /dev/shm/nodes.yml || echo "$MSG 15" >> $LOG
echo "- name: \"kibana\"" >> /dev/shm/nodes.yml || echo "$MSG 16" >> $LOG
echo "  dns: [\"kibana.local\"]" >> /dev/shm/nodes.yml || echo "$MSG 17" >> $LOG
echo "- name: \"logstash1\"" >> /dev/shm/nodes.yml || echo "$MSG 18" >> $LOG
echo "  dns: [\"logstash1.local\"]" >> /dev/shm/nodes.yml || echo "$MSG 19" >> $LOG
/usr/share/elasticsearch/bin/elasticsearch-certutil cert ca --pem --in /dev/shm/nodes.yml --out /etc/elasticsearch/certs.zip || echo "$MSG 20" >> $LOG
cd /etc/elasticsearch && unzip certs.zip || echo "$MSG 21" >> $LOG
for i in ca kibana logstash1 ; do chmod o+r /etc/elasticsearch/$i/* ; done >> $LOG
echo "### USER ADDED BELOW" >> /etc/elasticsearch/elasticsearch.yml || echo "$MSG 23" >>  $LOG
echo "xpack.security.enabled: true" >> /etc/elasticsearch/elasticsearch.yml || echo "$MSG 24" >> $LOG
echo "#xpack.security.http.ssl.enabled: true" >> /etc/elasticsearch/elasticsearch.yml || echo "$MSG 25" >> $LOG
echo "#xpack.security.http.ssl.key: logstash1/logstash1.key" >> /etc/elasticsearch/elasticsearch.yml || echo "$MSG 26" >> $LOG
echo "#xpack.security.http.ssl.certificate: logstash1/logstash1.crt" >> /etc/elasticsearch/elasticsearch.yml || echo "$MSG 27" >> $LOG
echo "#xpack.security.http.ssl.certificate_authorities: ca/ca.crt" >> /etc/elasticsearch/elasticsearch.yml || echo "$MSG 28" >> $LOG
echo "#xpack.security.transport.ssl.enabled: true" >> /etc/elasticsearch/elasticsearch.yml || echo "$MSG 29" >> $LOG
#sed -i "s/1g/500M/g" /etc/elasticsearch/jvm.options
service elasticsearch start || echo "$MSG 30" >> $LOG
echo y | /usr/share/elasticsearch/bin/elasticsearch-setup-passwords auto > /etc/elasticsearch/passwords.txt || echo "$MSG 31" >> $LOG
service elasticsearch stop && sed -i "s/#xpack\.security/xpack\.security/g" /etc/elasticsearch/elasticsearch.yml && service elasticsearch start
mv /etc/kibana/kibana.yml /etc/kibana/kibana.yml.bak
touch /etc/kibana/kibana.yml && chown kibana:kibana /etc/kibana/kibana.yml && chmod o+r /etc/kibana/kibana.yml
mkdir /var/log/kibana && chown kibana:kibana /var/log/kibana && chmod o+rx /var/log/kibana
touch /var/log/kibana/kibana.log && chown kibana:kibana /var/log/kibana/kibana.log && chmod o+rw /var/log/kibana/kibana.log
echo "server.port: 5601" >> /etc/kibana/kibana.yml
echo "server.host: \"localhost\"" >> /etc/kibana/kibana.yml
echo "elasticsearch.hosts: [\"https://127.0.0.1:9200\"]" >> /etc/kibana/kibana.yml
#echo "elasticsearch.username: \"kibana\"" >> /etc/kibana/kibana.yml
echo "elasticsearch.username: \"kibana_system\"" >> /etc/kibana/kibana.yml
echo "elasticsearch.password: changeme" >> /etc/kibana/kibana.yml
echo "elasticsearch.ssl.verificationMode: none" >> /etc/kibana/kibana.yml
# This changed in 7.8, we now have kibana and kibana_system passwords so we have to update grep to 'PASSWORD kibana ='
#cat /etc/elasticsearch/passwords.txt | grep "PASSWORD kibana =" | cut -d"=" -f2 | tr -d " " > /dev/shm/pass.txt
cat /etc/elasticsearch/passwords.txt | grep "PASSWORD kibana_system" | cut -d"=" -f2 | tr -d " " > /dev/shm/pass.txt
pass=$(cat /dev/shm/pass.txt) && sed -i "s/changeme/\"$pass\"/g" /etc/kibana/kibana.yml
echo "logging.dest: /var/log/kibana/kibana.log" >> /etc/kibana/kibana.yml
chmod o+r /etc/elasticsearch/kibana/*
echo "" > /etc/nginx/conf.d/default.conf
echo "server {" >> /etc/nginx/conf.d/default.conf
echo "  listen 443 default;" >> /etc/nginx/conf.d/default.conf
echo "  ssl on;" >> /etc/nginx/conf.d/default.conf
echo "  ssl_certificate /etc/elasticsearch/kibana/kibana.crt;" >> /etc/nginx/conf.d/default.conf
echo "  ssl_certificate_key /etc/elasticsearch/kibana/kibana.key;" >> /etc/nginx/conf.d/default.conf
echo "  location / {" >> /etc/nginx/conf.d/default.conf
echo "    proxy_pass http://localhost:5601/;" >> /etc/nginx/conf.d/default.conf
echo "  }" >> /etc/nginx/conf.d/default.conf
echo "}" >> /etc/nginx/conf.d/default.conf
setsebool -P httpd_can_network_connect 1 >> $LOG
service kibana start >> $LOG
service nginx stop && service nginx start >> $LOG
