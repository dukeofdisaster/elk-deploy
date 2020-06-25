#!/bin/bash
#
# cloud init script for full ELK 7.8 on centos 7
# TODO:
#	- better logging than >> $LOG
LOG=/var/log/user_data.sh.log

function apt_install_desired {
    sudo apt-get install curl nginx pwgen wget zip
}

function get_elastic_deb_tmp {
    cd /tmp
    wget -O /tmp/elasticsearch-7.8.0-amd64.deb https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.8.0-amd64.deb
    wget -O /tmp/elasticsearch-7.8.0-amd64.deb.sha512 https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.8.0-amd64.deb.sha512
    shasum -a 512 -c elasticsearch-7.8.0-amd64.deb.sha512 
}

function install_elastic_deb_tmp {
	cd /tmp
	dpkg -i elasticsearch-7.8.0-amd64.deb
}

function get_logstash_deb_tmp {
	cd /tmp
	wget -O /tmp/logstash-7.8.0.deb https://artifacts.elastic.co/downloads/logstash/logstash-7.8.0.deb
	wget -O /tmp/logstash-7.8.0.deb.sha512 https://artifacts.elastic.co/downloads/logstash/logstash-7.8.0.deb.sha512
	shasum -a 512 -c logstash-7.8.0.deb.sha512
}

function install_logstash_deb_tmp {
    cd /tmp
    dpkg -i logstash-7.8.0.deb
}

function get_kibana_deb_tmp {
    cd /tmp
    wget -O /tmp/kibana-7.8.0-amd64.deb https://artifacts.elastic.co/downloads/kibana/kibana-7.8.0-amd64.deb
    wget -O /tmp /kibana-7.8.0-amd64.deb.sha512 https://artifacts.elastic.co/downloads/kibana/kibana-7.8.0-amd64.deb.sha512
    shasum -a 512 -c kibana-7.8.0-amd64.deb.sha512
}

function install_kibana_deb_tmp {
    cd /tmp
    dpkg -i kibana-7.8.0-amd64.deb
}

function get_filebeat_deb_tmp {
    cd /tmp
    wget -O /tmp/filebeat-7.8.0-amd64.deb https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.8.0-amd64.deb
    wget -O /tmp/filebeat-7.8.0-amd64.deb.sha512 https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.8.0-amd64.deb.sha512
    shasum -a 512 -c filebeat-7.8.0-amd64.deb.sha512
}

function install_filebeat_deb_tmp {
    cd /tmp
    dpkg -i filebeat-7.8.0-amd64.deb
}

function add_local_names_hostsfile {
    cp /etc/hosts /etc/hosts.bak || echo "Backup of hosts file failed..." >> $LOG
    sed -i "s/localhost /localhost logstash\.local kibana\.local/g" /etc/hosts || echo "sed to add logstash.local and kibana.local failed" >> $LOG
}

function make_nodes_yml_for_certs {
    THIS="make_nodes_yml_for_certs"
    touch /dev/shm/nodes.yml || echo "$THIS 1" >> $LOG
    echo "instances:" >> /dev/shm/nodes.yml || echo "$THIS 2" >> $LOG
    echo "- name: \"kibana\"" >> /dev/shm/nodes.yml || echo "$THIS 3" >> $LOG
    echo "  dns: [\"kibana.local\"]" >> /dev/shm/nodes.yml || echo "$THIS 4" >> $LOG
    echo "- name: \"logstash\"" >> /dev/shm/nodes.yml || echo "$THIS 5" >> $LOG
    echo "  dns: [\"logstash.local\"]" >> /dev/shm/nodes.yml || echo "$THIS 6" >> $LOG
}

function gencerts_from_yml {
    THIS="gencerts_from_yml"
    [ -d /etc/elasticsearch ] &&
    mkdir /etc/elasticsearch/certs &&
    /usr/share/elasticsearch/bin/elasticsearch-certutil cert ca --pem --in /dev/shm/nodes.yml --out /etc/elasticsearch/certs/certs.zip || echo "$THIS 1" >> $LOG
    cd /etc/elasticsearch/certs && unzip certs.zip || echo "$THIS 2" >> $LOG
}

function make_certs_readable {
    THIS="make_certs_readable"
    for i in ca kibana logstash
    do 
        chmod o+r /etc/elasticsearch/certs/$i/*  || echo "$THIS failed on $i" >> $LOG
    done 
}

function add_cert_meta_to_elastic_yml {
    # NOTE: paths are relative to /etc/elasticsearch dir
    THIS="add_cert_meta_to_elastic_yml"
    echo "### USER ADDED BELOW" >> /etc/elasticsearch/elasticsearch.yml || echo "$THIS 1" >>  $LOG
    echo "xpack.security.enabled: true" >> /etc/elasticsearch/elasticsearch.yml || echo "$THIS 2" >> $LOG
    echo "#xpack.security.http.ssl.enabled: true" >> /etc/elasticsearch/elasticsearch.yml || echo "$THIS 3" >> $LOG
    echo "#xpack.security.http.ssl.key: certs/logstash/logstash.key" >> /etc/elasticsearch/elasticsearch.yml || echo "$THIS 4" >> $LOG
    echo "#xpack.security.http.ssl.certificate: certs/logstash/logstash.crt" >> /etc/elasticsearch/elasticsearch.yml || echo "$THIS 5" >> $LOG
    echo "#xpack.security.http.ssl.certificate_authorities: certs/ca/ca.crt" >> /etc/elasticsearch/elasticsearch.yml || echo "$THIS 6" >> $LOG
    echo "#xpack.security.transport.ssl.enabled: true" >> /etc/elasticsearch/elasticsearch.yml || echo "$THIS 7" >> $LOG
}
#sed -i "s/1g/500M/g" /etc/elasticsearch/jvm.options

function start_elastic_and_genpasswords {
    THIS="start_elastic_and_gen_passwords"
    service elasticsearch start || echo "$THIS 1" >> $LOG
    echo y | /usr/share/elasticsearch/bin/elasticsearch-setup-passwords auto > /etc/elasticsearch/passwords.txt || echo "$THIS 2" >> $LOG
    service elasticsearch stop && sed -i "s/#xpack\.security/xpack\.security/g" /etc/elasticsearch/elasticsearch.yml && service elasticsearch start
}

function setup_basic_kibana_yml {
    THIS="setup_basic_kibana_yml"
    mv /etc/kibana/kibana.yml /etc/kibana/kibana.yml.bak || echo "$THIS 1" >> $LOG
    touch /etc/kibana/kibana.yml && chown kibana:kibana /etc/kibana/kibana.yml && chmod o+r /etc/kibana/kibana.yml || echo "$THIS 2" >> $LOG
    mkdir /var/log/kibana && chown kibana:kibana /var/log/kibana && chmod o+rx /var/log/kibana || echo "THIS 3" >> $LOG
    touch /var/log/kibana/kibana.log && chown kibana:kibana /var/log/kibana/kibana.log && chmod o+rw /var/log/kibana/kibana.log || echo "$THIS 4" >> $LOG
    echo "server.port: 5601" >> /etc/kibana/kibana.yml || echo "$THIS 5" >> $LOG
    echo "server.host: \"localhost\"" >> /etc/kibana/kibana.yml || echo "$THIS 6" >> $LOG
    echo "elasticsearch.hosts: [\"https://127.0.0.1:9200\"]" >> /etc/kibana/kibana.yml || echo "$THIS 7" >> $LOG
    echo "elasticsearch.username: \"kibana_system\"" >> /etc/kibana/kibana.yml || echo "$THIS 8" >> $LOG
    echo "elasticsearch.password: changeme" >> /etc/kibana/kibana.yml || echo "$THIS 9" >> $LOG
    echo "elasticsearch.ssl.verificationMode: none" >> /etc/kibana/kibana.yml || echo "$THIS 10" >> $LOG
    # This changed in 7.8, we now have kibana and kibana_system passwords so we put kibana_system in the kibana.yml
    cat /etc/elasticsearch/passwords.txt | grep "PASSWORD kibana_system" | cut -d"=" -f2 | tr -d " " > /dev/shm/pass.txt || echo "$THIS 11" >> $LOG
    pass=$(cat /dev/shm/pass.txt) && sed -i "s/changeme/\"$pass\"/g" /etc/kibana/kibana.yml || echo "$THIS 12" >> $LOG
    echo "logging.dest: /var/log/kibana/kibana.log" >> /etc/kibana/kibana.yml || echo "$THIS 12" >> $LOG
}

function make_nginx_default_conf {
    THIS="make_nginx_default_conf"
    echo "" > /etc/nginx/conf.d/default.conf || echo "$THIS 1" >> $LOG
    echo "server {" >> /etc/nginx/conf.d/default.conf || echo "$THIS 2" >> $LOG
    echo "  listen 443 default;" >> /etc/nginx/conf.d/default.conf || echo "$THIS 3" >> $LOG
    echo "  ssl on;" >> /etc/nginx/conf.d/default.conf || echo "$THIS 4" >> $LOG
    echo "  ssl_certificate /etc/elasticsearch/certs/kibana/kibana.crt;" >> /etc/nginx/conf.d/default.conf || echo "$THIS 5" >> $LOG
    echo "  ssl_certificate_key /etc/elasticsearch/certs/kibana/kibana.key;" >> /etc/nginx/conf.d/default.conf || echo "$THIS 6" >> $LOG
    echo "  location / {" >> /etc/nginx/conf.d/default.conf || echo "$THIS 7" >> $LOG
    echo "    proxy_pass http://localhost:5601/;" >> /etc/nginx/conf.d/default.conf || echo "$THIS 8" >> $LOG
    echo "  }" >> /etc/nginx/conf.d/default.conf || echo "$THIS 9" >> $LOG
    echo "}" >> /etc/nginx/conf.d/default.conf || echo "$THIS 10" >> $LOG
}

function get_debs_all {
    get_elastic_deb_tmp
    get_logstash_deb_tmp
    get_kibana_deb_tmp
    get_filebeat_deb_tmp
}

function install_debs_all {
  install_elastic_deb_tmp
  install_logstash_deb_tmp
  install_kibana_deb_tmp
  install_filebeat_deb_tmp
}

# - 1
#apt_install_desired
# - 2
#get_debs_all && echo "get_debs_uall succes" >> $LOG
# -3 
#install_debs_all && echo "install_debs_all success" >> $LOG
# - 4 
#add_local_names_hostsfile && echo "add_local_names_hostsfile success" >> $LOG
# - 5 
#make_nodes_yml_for_certs && echo "make_nodes_yml_for_certs success" >> $LOG
# - 6 
#gencerts_from_yml && echo "gencerts_from_yml success" >> $LOG
# - 7 
#make_certs_readable && echo "make_certs_readable success" >> $LOG
# - 8 
#add_cert_meta_to_elastic_yml && echo "add_certs_meta_to_elastic_yml success" >> $LOG
# - 9 
#start_elastic_and_genpasswords && echo "start_elastic_and_genpasswords success" >> $LOG
# - 10
#setup_basic_kibana_yml && echo "setup_basic_kibana_yml success" >> $LOG
# - 11
#make_nginx_default_conf && echo "make_nginx_default_conf success" >> $LOG
#service kibana start >> $LOG
#service nginx start >> $LOG
