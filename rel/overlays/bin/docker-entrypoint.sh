#!/bin/sh
set -e

# Ensure the database directory exists and is writable by nobody user
if [ -n "$DATABASE_PATH" ]; then
  DB_DIR=$(dirname "$DATABASE_PATH")

  # Create the directory if it doesn't exist
  mkdir -p "$DB_DIR"

  # Ensure the directory and any existing database file are owned by nobody
  chown -R nobody:root "$DB_DIR"
  chmod -R 755 "$DB_DIR"
fi

# Drop privileges and execute the command as nobody user
exec gosu nobody "$@"
