#!/bin/bash
# This script inspired by facebook utils
# It's ruby based on knife execute
# Well, change ruby based knife to shell

# Check if it's root user
if [[ $EUID -ne 0 ]]; then
  echo "You must be a root user" 2>&1
  exit 1
fi

# Global ENV define
PATH="/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin"

embedded_path='/opt/opscode/embedded/bin'
ctl_bin='/opt/opscode/bin/chef-server-ctl'

private_file='/etc/opscode/private-chef-secrets.json'

# Show running services
service_list() {

  if ${ctl_bin} service-list ; then
    echo
  else
    echo "ERROR: Fail to get service list"
    exit 1
  fi
}

# Collect Server Status
get_server_status() {
  chef_url='https://localhost/_status'
  output=$(curl -s -k "${chef_url}")
  server_status=$(echo "${output}" | python -c 'import sys, json; print json.load(sys.stdin)["status"]')
  if [ "${server_status}" == "pong" ]; then
    echo "Server status is fine"
  else
    echo "${server_status}"
    exit
  fi
}

# Collect Redis status
get_redis_status() {
  redis_password=$(python -c 'import sys, json; print json.load(sys.stdin)["redis_lb"]["password"]' < ${private_file})
  "${embedded_path}"/redis-cli -p 16379 -a "${redis_password}" "info"
}

# Collect Rabbitmq status
get_rabbitmq_status() {
  PATH=${PATH}:${embedded_path}
  "${embedded_path}"/rabbitmqctl status
  echo -e "\nPrint messages ready number"
  "${embedded_path}"/rabbitmqctl list_queues -p /chef messages_ready | sed '/.../d' | awk 'END {print NR}'

}

# Collect Postgresql status
get_postgresql_status() {
  SQL_BIN=${embedded_path}/psql

  for i in seq_scan seq_tup_read idx_scan idx_tup_fetch n_tup_ins n_tup_upd n_tup_del n_live_tup n_dead_tup
    do
      Q="SELECT SUM(${i}) FROM pg_stat_all_tables;"
      NUMBER=$(su opscode-pgsql -c "cd; ${SQL_BIN} -A -P tuples_only -U opscode-pgsql -d opscode_chef -c '${Q}'")
      echo -e "\n ${i} is total number ${NUMBER}"
  done

  # connection count
  COUNT_QUERY="SELECT count(*) FROM pg_stat_activity WHERE datname = 'opscode_chef';"
  COUNT_NUMBER=$(su opscode-pgsql -c "cd; ${SQL_BIN} -A -P tuples_only -U opscode-pgsql -d opscode_chef -c \"${COUNT_QUERY}\"")
  echo -e "\nPSQL Connection Count Number: ${COUNT_NUMBER}"
}

echo -e "\nChef Server Running Service\n"
service_list
echo -e "\n"
echo "---------------------------"
get_server_status
echo -e "\n"
echo "---------------------------"
echo "Redis Status"
get_redis_status
echo -e "\n"
echo "---------------------------"
echo "Get RabbitMQ Status"
get_rabbitmq_status
echo -e "\n"
echo "---------------------------"
echo "Get Postgresql Status"
get_postgresql_status