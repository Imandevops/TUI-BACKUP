#!/bin/bash

BACKUP_DIR="/var/backups/ImanBackup"
mkdir -p "$BACKUP_DIR"

# === Utilities ===
prompt_input() {
  local title="$1"
  local label="$2"
  dialog --title "$title" --inputbox "$label" 8 60 3>&1 1>&2 2>&3
}

prompt_pass() {
  local title="$1"
  local label="$2"
  dialog --title "$title" --insecure --passwordbox "$label" 8 60 3>&1 1>&2 2>&3
}

msg_info() {
  dialog --title "ℹ️ Info" --msgbox "$1" 10 60
}

msg_error() {
  dialog --title "❌ Error" --msgbox "$1" 10 60
}

# === Backup Functions ===

backup_mysql() {
  host=$(prompt_input "MySQL Backup" "Enter Host:") || return
  port=$(prompt_input "MySQL Backup" "Enter Port (default 3306):") || return
  port=${port:-3306}
  user=$(prompt_input "MySQL Backup" "Enter Username:") || return
  pass=$(prompt_pass "MySQL Backup" "Enter Password:") || return
  db=$(prompt_input "MySQL Backup" "Enter Database Name:") || return

  # Test connection
  mysql -h "$host" -P "$port" -u "$user" -p"$pass" -e ";" 2>/tmp/mysql_conn_err
  if [[ $? -ne 0 ]]; then
    msg_error "Connection error:\n$(cat /tmp/mysql_conn_err)"
    return
  fi

  # Check if DB exists
  if ! mysql -h "$host" -P "$port" -u "$user" -p"$pass" -e "USE $db;" 2>/tmp/mysql_db_err; then
    msg_error "Database does not exist:\n$(cat /tmp/mysql_db_err)"
    return
  fi

  filename="$BACKUP_DIR/mysql_${db}_$(date +%F_%H-%M-%S).sql.gz"
  if ! mysqldump -h "$host" -P "$port" -u "$user" -p"$pass" "$db" 2>/tmp/mysql_dump_err | gzip > "$filename"; then
    msg_error "Backup failed:\n$(cat /tmp/mysql_dump_err)"
    return
  fi

  msg_info "✅ MySQL backup saved:\n$filename"
}

backup_postgres() {
  host=$(prompt_input "PostgreSQL Backup" "Enter Host:")
  port=$(prompt_input "PostgreSQL Backup" "Enter Port (default 5432):")
  port=${port:-5432}
  user=$(prompt_input "PostgreSQL Backup" "Enter Username:")
  db=$(prompt_input "PostgreSQL Backup" "Enter Database Name:")
  pass=$(prompt_pass "PostgreSQL Backup" "Enter Password:")

  export PGPASSWORD="$pass"
  if ! pg_isready -h "$host" -p "$port" > /dev/null 2>&1; then
    msg_error "PostgreSQL server is not reachable."
    return
  fi

  if ! psql -h "$host" -p "$port" -U "$user" -lqt | cut -d \| -f 1 | grep -qw "$db"; then
    msg_error "Database \"$db\" does not exist."
    return
  fi

  filename="$BACKUP_DIR/postgres_${db}_$(date +%F_%H-%M-%S).dump"
  if ! pg_dump -h "$host" -p "$port" -U "$user" -F c "$db" > "$filename" 2>/tmp/pg_dump_err; then
    msg_error "Backup failed:\n$(cat /tmp/pg_dump_err)"
    return
  fi

  msg_info "✅ PostgreSQL backup saved:\n$filename"
}

backup_mongodb() {
  host=$(prompt_input "MongoDB Backup" "Enter Host:")
  port=$(prompt_input "MongoDB Backup" "Enter Port (default 27017):")
  port=${port:-27017}
  db=$(prompt_input "MongoDB Backup" "Enter Database Name:")

  if ! mongosh --quiet --host "$host" --port "$port" --eval "db.getMongo().getDBNames().indexOf('$db') >= 0" | grep -q true; then
    msg_error "MongoDB database \"$db\" does not exist or connection failed."
    return
  fi

  filename="$BACKUP_DIR/mongo_${db}_$(date +%F_%H-%M-%S)"
  mongodump --host "$host" --port "$port" --db "$db" --out "$filename"
  msg_info "✅ MongoDB backup saved:\n$filename"
}

backup_redis() {
  host=$(prompt_input "Redis Backup" "Enter Host (default 127.0.0.1):")
  host=${host:-127.0.0.1}
  port=$(prompt_input "Redis Backup" "Enter Port (default 6379):")
  port=${port:-6379}

  if ! redis-cli -h "$host" -p "$port" ping | grep -q PONG; then
    msg_error "Redis is not reachable."
    return
  fi

  filename="$BACKUP_DIR/redis_$(date +%F_%H-%M-%S).rdb"
  redis-cli -h "$host" -p "$port" save

  REDIS_DUMP=$(redis-cli -h "$host" -p "$port" CONFIG GET dir | awk 'NR==2')/dump.rdb
  if [[ -f "$REDIS_DUMP" ]]; then
    cp "$REDIS_DUMP" "$filename"
    msg_info "✅ Redis RDB backup saved:\n$filename"
  else
    msg_error "Failed to locate Redis dump file."
  fi
}

backup_cassandra() {
  keyspace=$(prompt_input "Cassandra Backup" "Enter Keyspace:")
  filename="$BACKUP_DIR/cassandra_${keyspace}_$(date +%F_%H-%M-%S)"

  mkdir -p "$filename"
  if ! nodetool snapshot -t "${keyspace}_snap" "$keyspace" 2>/tmp/cassandra_snap_err; then
    msg_error "Failed to snapshot Cassandra keyspace:\n$(cat /tmp/cassandra_snap_err)"
    return
  fi
  cp -r /var/lib/cassandra/data/$keyspace/*/snapshots/* "$filename" 2>/dev/null || true
  msg_info "✅ Cassandra snapshot saved:\n$filename"
}

backup_elasticsearch() {
  host=$(prompt_input "Elasticsearch Backup" "Enter Host (default 127.0.0.1):") || return
  host=${host:-127.0.0.1}
  port=$(prompt_input "Elasticsearch Backup" "Enter Port (default 9200):") || return
  port=${port:-9200}
  repo=$(prompt_input "Elasticsearch Backup" "Enter Snapshot Repository Name:") || return
  snap="snapshot_$(date +%F_%H-%M-%S)"

  response=$(curl -s -X PUT "http://$host:$port/_snapshot/$repo/$snap?wait_for_completion=true" -H 'Content-Type: application/json' -d '{}')
  if echo "$response" | grep -q '"accepted":true\|"success":true\|"snapshot"'; then
    msg_info "✅ Elasticsearch snapshot \"$snap\" created in repository \"$repo\""
  else
    msg_error "Failed to create snapshot.\n$response"
  fi
}

# === Main Menu ===
main_menu() {
  while true; do
    CHOICE=$(dialog --title " Backup :) TUI" --menu "Select a database to back up:" 18 60 10 \
      1 "MySQL / MariaDB" \
      2 "PostgreSQL" \
      3 "MongoDB" \
      4 "Redis" \
      5 "Cassandra" \
      6 "Elasticsearch" \
      7 "Exit" 3>&1 1>&2 2>&3)

    case "$CHOICE" in
      1) backup_mysql ;;
      2) backup_postgres ;;
      3) backup_mongodb ;;
      4) backup_redis ;;
      5) backup_cassandra ;;
      6) backup_elasticsearch ;;
      7) clear; exit 0 ;;
    esac
  done
}

main_menu

