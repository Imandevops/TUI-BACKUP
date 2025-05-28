# 🛡️ Terminal Backup Utility

A powerful interactive **Terminal UI (TUI)** backup utility written in Bash for managing backups of common databases:

- MySQL / MariaDB
- PostgreSQL
- MongoDB
- Redis
- Cassandra
- Elasticsearch

Powered by [`dialog`](https://invisible-island.net/dialog/) for a clean and intuitive terminal interface.

---

## 📦 Features

- Interactive menu for selecting database type
- Secure password input (hidden entry)
- Automatic backup file naming with timestamp
- Connection and database existence checks
- Compressed backups (e.g. MySQL `.sql.gz`)
- PostgreSQL custom format dumps
- Snapshot creation for Cassandra and Elasticsearch
- Error reporting via popups

---

## 🖥️ Requirements

- `bash` (standard in Linux/macOS)
- [`dialog`](https://invisible-island.net/dialog/) (for TUI popups)
- Appropriate database clients:
  - `mysql`, `mysqldump`
  - `psql`, `pg_dump`, `pg_isready`
  - `mongosh`, `mongodump`
  - `redis-cli`
  - `nodetool` (Cassandra)
  - `curl` (Elasticsearch snapshot API)

### ✅ Install `dialog`

**macOS (with Homebrew):**
```bash
brew install dialog
```

**Ubuntu/Debian:**
```bash
sudo apt install dialog
```

**RHEL/CentOS/Fedora:**
```bash
sudo dnf install dialog
# or
sudo yum install dialog
```

---

## 🚀 How to Use
1.	Clone or copy the script to your local machine.
2.	Make it executable:
```bash
chmod +x db.sh
```

3.	Run the script:
```bash
./db.sh
```

4.	Follow the on-screen menus to select a database and provide connection details.

Backups are stored in:
`/var/backups/ImanBackup`

You may need sudo if the script cannot write to that directory.

---

## 📁 Backup Output Format

| Database      | Output Format                       |
|---------------|--------------------------------------|
| MySQL/MariaDB | `mysql_<DBNAME>_<TIMESTAMP>.sql.gz` |
| PostgreSQL    | `postgres_<DBNAME>_<TIMESTAMP>.dump`|
| MongoDB       | Directory: `mongo_<DBNAME>_<TIMESTAMP>/` |
| Redis         | `redis_<TIMESTAMP>.rdb`             |
| Cassandra     | Directory: `cassandra_<KEYSPACE>_<TIMESTAMP>/` |
| Elasticsearch | Snapshot in specified repository    |

---

## 📜 License
MIT License © 2025 [Iman](https://github.com/Imandevops) (Adapted by [EmArTx](https://github.com/emartx))

---
