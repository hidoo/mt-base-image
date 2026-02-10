#!/bin/bash
set -e

# If arguments are passed and the first is not a flag, run them directly
# This allows: docker run <image> perl -e '...'
if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
    exec "$@"
fi

# Default: start Proclet
cd /app/movabletype
exec proclet start --procfile /etc/proclet/Procfile "$@"
