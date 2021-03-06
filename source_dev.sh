#!/bin/bash
################################################################################
# Setup a dev environment
#
# Usage:
#  source source_dev.sh
################################################################################

if [ -z "$1" ]; then
    VENV_ROOT="$HOME/.venvs"
else
    VENV_ROOT="$1"
fi

ls $VENV_ROOT 2&>1 /dev/null

if [ "$?" -gt 0 ]; then
    mkdir -p $VENV_ROOT && python3 -m venv $VENV_ROOT/scatter
fi

. $VENV_ROOT/scatter/bin/activate
