#!/bin/bash
set -e

cd /app/movabletype
exec proclet start --procfile /etc/proclet/Procfile "$@"
