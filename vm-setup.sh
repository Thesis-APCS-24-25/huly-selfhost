#!/usr/bin/env bash

HULY_VERSION="latest"
DOCKER_NAME="huly"
CONFIG_FILE="huly.conf"

# Default values for configuration
_HOST_ADDRESS="localhost"
_HTTP_PORT="80"
_SECURE="" # Default to not secure (no SSL)

# Parse command-line arguments for non-interactive configuration
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --host-address)
            _HOST_ADDRESS="$2"
            shift
            ;;
        --http-port)
            _HTTP_PORT="$2"
            ;;
        --secure)
            _SECURE="true"
            ;;
        --secret)
            SECRET=true
            ;;
        *)
            # Ignore unknown arguments to allow for future extensions
            ;;
    esac
    shift
done

# Validate HTTP_PORT
if ! [[ "$_HTTP_PORT" =~ ^[0-9]+$ && "$_HTTP_PORT" -ge 1 && "$_HTTP_PORT" -le 65535 ]]; then
    echo "Error: Invalid HTTP port specified. Please provide a number between 1 and 65535."
    exit 1
fi

echo "$_HOST_ADDRESS $_HTTP_PORT"

# Determine if SSL should be used based on host address or --secure flag
if [[ "$_HOST_ADDRESS" == "localhost" || "$_HOST_ADDRESS" == "127.0.0.1" || "$_HOST_ADDRESS" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}:?$ ]]; then
    _HOST_ADDRESS="${_HOST_ADDRESS%:}:${_HTTP_PORT}"
    _SECURE="" # Force non-secure for localhost/IP addresses if not explicitly set by --secure
else
    # If a domain name is used and --secure wasn't passed, _SECURE remains its default empty value
    # If --secure was passed, it will be "true"
    : # No action needed, _SECURE is already set or default
fi


SECRET=false
if [ "$1" == "--secret" ]; then
  SECRET=true
fi

if [ ! -f .huly.secret ] || [ "$SECRET" == true ]; then
  openssl rand -hex 32 > .huly.secret
  echo "Secret generated and stored in .huly.secret"
else
  echo -e "\033[33m.huly.secret already exists, not overwriting."
  echo "Run this script with --secret to generate a new secret."
fi


export HOST_ADDRESS=$_HOST_ADDRESS
export SECURE=$_SECURE
export HTTP_PORT=$_HTTP_PORT
export HTTP_BIND=$HTTP_BIND # This variable was not defined in the original interactive script. It might need to be sourced from somewhere or set to a default.
export TITLE=${TITLE:-Huly}
export DEFAULT_LANGUAGE=${DEFAULT_LANGUAGE:-en}
export LAST_NAME_FIRST=${LAST_NAME_FIRST:-true}
export HULY_SECRET=$(cat .huly.secret)
export HULY_VERSION=$HULY_VERSION

envsubst < .template.huly.conf > "$CONFIG_FILE"

echo -e "\n\033[1;34mConfiguration Summary:\033[0m"
echo -e "Host Address: \033[1;32m$_HOST_ADDRESS\033[0m"
echo -e "HTTP Port: \033[1;32m$_HTTP_PORT\033[0m"
if [[ -n "$_SECURE" ]]; then
    echo -e "SSL Enabled: \033[1;32mYes\033[0m"
else
    echo -e "SSL Enabled: \033[1;31mNo\033[0m"
fi

echo -e "\033[1;32mRunning 'docker compose up -d' now...\033[0m"
docker compose up -d

echo -e "\033[1;32mSetup is complete!\n Generating nginx.conf...\033[0m"
./nginx.sh
