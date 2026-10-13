#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
./logo-service/logo-service &
logo_pid=$!
trap 'kill "$logo_pid" 2>/dev/null || true' EXIT
./app/borne_dons
