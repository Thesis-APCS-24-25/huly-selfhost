#!/bin/bash

# --- Function to wait for APT locks ---
wait_for_apt_locks() {
    echo "Waiting for APT locks to be released..."
    max_attempts=60 # Wait for up to 60 * 5 seconds = 5 minutes
    attempt=0

    while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
          fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
          fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
        if [ "$attempt" -ge "$max_attempts" ]; then
            echo "Error: APT locks still held after $max_attempts attempts. Exiting."
            exit 1
        fi
        echo "APT lock detected. Waiting 5 seconds... (Attempt $((attempt+1))/$max_attempts)"
        sleep 5
        attempt=$((attempt+1))
    done
    echo "APT locks released."
}

# Exit immediately if a command exits with a non-zero status.
set -e

# 1. Install Docker
# For Ubuntu/Debian:
if ! command -v docker &> /dev/null
then
    wait_for_apt_locks
    echo "Installing Docker..."
    apt-get update
    echo "Installing prerequisites..."
    wait_for_apt_locks
    apt-get install -y apt-transport-https ca-certificates curl gnupg
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" | sudo tee \
        /etc/apt/sources.list.d/docker.list > /dev/null
    wait_for_apt_locks
    apt-get update
    echo "Installing Docker packages..."
    wait_for_apt_locks
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # For startup scripts, the user is root, so this might not be strictly necessary for the script itself,
    # but good for post-login access.
    echo "Docker installed."
else
    echo "Docker already installed."
fi

# Login to google cloud artifact registry
gcloud auth print-access-token | docker login \
    -u oauth2accesstoken \
    --password-stdin https://asia-southeast1-docker.pkg.dev

git clone https://github.com/Thesis-APCS-24-25/huly-selfhost.git
cd huly-selfhost
./cloud-instance-setup.sh
mkdir -p /etc/nginx/sites-enabled/
ln -sf $(pwd)/nginx.conf /etc/nginx/sites-enabled/huly.conf
docker container exec huly-nginx-1 nginx -s reload
