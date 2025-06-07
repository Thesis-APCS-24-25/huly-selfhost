#!/bin/bash

# Load configuration from huly.conf if it exists
if [ -f "huly.conf" ]; then
    source "huly.conf"
fi

# Set default values for variables if not sourced from huly.conf
HOST_ADDRESS=${HOST_ADDRESS:-localhost}
HTTP_BIND=${HTTP_BIND:-127.0.0.1}
HTTP_PORT=${HTTP_PORT:-80}
SECURE=${SECURE:-} # Default to empty (not secure)

# Check for --recreate flag (now handled as a simple argument check)
RECREATE=false
if [ "$1" == "--recreate" ]; then
    RECREATE=true
fi

# Handle nginx.conf recreation or updating
if [ "$RECREATE" == true ]; then
    cp .template.nginx.conf nginx.conf
    echo "nginx.conf has been recreated from the template."
else
    if [ ! -f "nginx.conf" ]; then
        echo "nginx.conf not found, creating from template."
        cp .template.nginx.conf nginx.conf
    else
        echo "nginx.conf already exists. Only updating server_name, listen, and proxy_pass."
        echo "Run with --recreate to fully overwrite nginx.conf."
    fi
fi

# Update server_name and proxy_pass using sed
sed -i.bak "s|server_name .*;|server_name ${HOST_ADDRESS};|" ./nginx.conf
sed -i.bak "s|proxy_pass .*;|proxy_pass http://${HTTP_BIND}:${HTTP_PORT};|" ./nginx.conf

# Update listen directive to either port 80 or 443, while preserving IP address
if [[ -n "$SECURE" ]]; then
    # Secure (use port 443 and add 'ssl')
    sed -i.bak -E 's|(listen )(.*:)?([0-9]+)?;|\1\2443 ssl;|' ./nginx.conf
    echo "Serving over SSL. Make sure to add your SSL certificates."
else
    # Non-secure (use port 80 and remove 'ssl' if it exists, or set to 80)
    sed -i.bak -E "s|(listen )(.*:)?([0-9]+) ssl;|\1\280;|" ./nginx.conf # First, remove 'ssl' if present
    sed -i.bak -E "s|(listen )(.*:)?([0-9]+)?;|\1\280;|" ./nginx.conf    # Then, ensure it's port 80
fi

# Extract IP address for redirect configuration (from the updated nginx.conf)
# This assumes the 'listen' directive will have an IP if it's there.
IP_ADDRESS=$(grep -oE 'listen \K[^:]+(?=:[0-9]+)' nginx.conf | head -n 1) # Grab the first one

# Handle HTTP to HTTPS redirect server block
if [[ -n "$SECURE" ]]; then # If SECURE is true (SSL enabled)
    echo "Configuring HTTP to HTTPS redirect..."

    # Remove any existing redirect block to prevent duplicates
    if grep -q 'return 301 https://\$host\$request_uri;' nginx.conf; then
        sed -i.bak '/# ! DO NOT REMOVE COMMENT/,/# DO NOT REMOVE COMMENT !/d' nginx.conf
    fi

    # Append the HTTP to HTTPS redirect block
    echo -e "\n# ! DO NOT REMOVE COMMENT" >> ./nginx.conf
    echo -e "# DO NOT MODIFY, CHANGES WILL BE OVERWRITTEN" >> ./nginx.conf
    echo -e "server {" >> ./nginx.conf
    echo -e "    listen ${IP_ADDRESS:+${IP_ADDRESS}:}80;" >> ./nginx.conf
    echo -e "    server_name ${HOST_ADDRESS};" >> ./nginx.conf
    echo -e "    return 301 https://\$host\$request_uri;" >> ./nginx.conf
    echo -e "}" >> ./nginx.conf
    echo -e "# DO NOT REMOVE COMMENT !" >> ./nginx.conf
else # If SECURE is false (SSL disabled)
    echo "SSL is disabled; ensuring HTTP to HTTPS redirect is removed."
    # Remove the entire server block for port 80 if it exists
    if grep -q 'return 301 https://\$host\$request_uri;' nginx.conf; then
        sed -i.bak '/# ! DO NOT REMOVE COMMENT/,/# DO NOT REMOVE COMMENT !/d' nginx.conf
        echo "HTTP to HTTPS redirect block removed."
    fi
fi

echo -e "\033[1;32mRunning 'sudo nginx -s reload' now...\033[0m"
sudo docker container exec huly-nginx-1 nginx -s reload

echo -e "\033[1;32mNginx configuration updated and reloaded.\033[0m"
