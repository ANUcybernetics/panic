---
id: task-19
title: >-
  make regular backups of the sqlite db file (inc. a way to restore from them,
  for changing machines)
status: To Do
assignee: []
created_date: "2025-07-08"
labels:
  - reliability
  - backup
dependencies: []
---

## Description

This app runs on a fly.io machine and uses the attached storage for the sqlite
database file (see @fly.toml).

What's the best way to backup the sqlite database file? A script which (if run
on a sufficiently-authenticated machine) can download a backup (perhaps using
the fly tailscale stuff)? Or to expose it as a web endpoint to download the file
via the webserver? And what's the best way to download a copy of the "prod"
sqlite db file for a point-in-time snapshot without corrupting either the
original or the backup?

## Implementation notes

For SQLite backups, there are a few reliable approaches to consider:

### Option 1: SQLite backup API (recommended)

Use SQLite's built-in backup API via the `.backup` command or `VACUUM INTO` SQL
command. This ensures a consistent snapshot even while the database is being
written to.

```elixir
# Example using Ecto.Adapters.SQL
Ecto.Adapters.SQL.query!(Panic.Repo, "VACUUM INTO '/path/to/backup.db'")
```

### Option 2: Fly.io volumes snapshots

Since the app runs on Fly.io with attached storage, you could use Fly's volume
snapshots:

- `fly volumes snapshots create <volume-id>` creates a point-in-time snapshot
- Snapshots can be restored to new volumes for disaster recovery
- Could be automated via a cron job or scheduled task
- **Cost**: No additional charge (included with volume at $0.15/GB/month)
- **Size**: Full volume size (not just used space)
- **Retention**: 5 days by default, configurable up to 60 days

### Option 3: WAL mode with safe copying

If the database is in WAL (Write-Ahead Logging) mode, you can safely copy the
database file and its WAL file while the database is running:

1. Copy the main `.db` file
2. Copy the `.db-wal` file (if it exists)
3. Copy the `.db-shm` file (if it exists)

### Recommended approach

Given the Fly.io deployment and that snapshots are free but capture the full volume:

1. **For disaster recovery**: Rely on Fly's automatic daily snapshots (free, 5-day retention)
2. **For efficient backups**: Since snapshots capture the full volume (potentially wasteful for small DBs), implement a backup endpoint that:

   - Uses `VACUUM INTO` to create a temporary backup file
   - Streams the backup file as a download
   - Deletes the temporary file after streaming

3. **For restoration**:
   - Upload the backup file via secure transfer (SSH/SCP via Fly's Tailscale)
   - Stop the app temporarily
   - Replace the database file
   - Restart the app

### Security considerations

- Any backup endpoint should require strong authentication (e.g., API key)
- Consider encrypting backups at rest
- Rotate old backups to manage storage costs
- Test restoration process regularly
