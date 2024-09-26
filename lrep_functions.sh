#!/bin/sh

# /usr/local/lib/lrep_functions.sh
# Common functions for lrep

# Load configuration
. /etc/lrep.conf

# Function to check for required commands
check_requirements() {
    missing=0
    for cmd in dpkg-scanpackages apt-ftparchive gpg; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Error: Required command '$cmd' not found."
            missing=1
        fi
    done
    if [ "$missing" -ne 0 ]; then
        echo "Please install the missing commands and try again."
        exit 1
    fi
}

# Logging function
log() {
    message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | sudo tee -a "$LOG_FILE" >/dev/null
}

# Function to update the local repository
update_local_repo() {
    log "Starting repository update."

    # Ensure we have necessary permissions
    if [ ! -w "$LOCAL_REPO_DIR" ]; then
        echo "Error: Write permission denied on $LOCAL_REPO_DIR."
        exit 1
    fi

    echo "Updating local repository..."

    # Generate the Packages.gz file
    (cd "$LOCAL_REPO_DIR" && \
        dpkg-scanpackages "pool/$COMPONENT" /dev/null | \
        sudo tee "dists/$DIST_NAME/$COMPONENT/binary-$ARCH/Packages" | \
        gzip -9c | sudo tee "dists/$DIST_NAME/$COMPONENT/binary-$ARCH/Packages.gz" >/dev/null)

    # Generate the Release file
    apt-ftparchive  \
        -o APT::FTPArchive::Release::Origin="Local" \
        -o APT::FTPArchive::Release::Label="Local" \
        -o APT::FTPArchive::Release::Suite="$DIST_NAME" \
        -o APT::FTPArchive::Release::Codename="$DIST_NAME" \
        -o APT::FTPArchive::Release::Architectures="$ARCH" \
        -o APT::FTPArchive::Release::Components="$COMPONENT" \
        release "$LOCAL_REPO_DIR/dists/$DIST_NAME" | sudo tee "$LOCAL_REPO_DIR/dists/$DIST_NAME/Release" >/dev/null

    # Sign the Release file to create Release.gpg and InRelease
    sudo gpg --homedir "$PRIVATE_KEY_DIR" --default-key 'LocalRepositoryKey' --batch --yes --detach-sign \
        --armor --output "$LOCAL_REPO_DIR/dists/$DIST_NAME/Release.gpg" "$LOCAL_REPO_DIR/dists/$DIST_NAME/Release"
    sudo gpg --homedir "$PRIVATE_KEY_DIR" --default-key 'LocalRepositoryKey' --batch --yes --clearsign \
        --output "$LOCAL_REPO_DIR/dists/$DIST_NAME/InRelease" "$LOCAL_REPO_DIR/dists/$DIST_NAME/Release"

    echo "Local repository updated successfully."
    log "Repository update completed."
}

# Function to list all packages in the local repository
list_local_repo() {
    echo "Packages in local repository:"
    if [ -d "$LOCAL_REPO_DIR/pool/$COMPONENT" ]; then
        ls -1 "$LOCAL_REPO_DIR/pool/$COMPONENT/"*.deb 2>/dev/null || echo "No packages found in local repository."
    else
        echo "No packages found in local repository."
    fi
}

# Function to validate a .deb file
validate_deb_file() {
    local deb_file="$1"
    if dpkg --info "$deb_file" >/dev/null 2>&1; then
        return 0
    else
        echo "Error: '$deb_file' is not a valid Debian package."
        return 1
    fi
}

# Function to add a deb file to the local repository and update the repository
add_to_local_repo() {
    local deb_file="$1"

    if ! validate_deb_file "$deb_file"; then
        exit 1
    fi

    # Ensure we have necessary permissions
    if [ ! -w "$LOCAL_REPO_DIR/pool/$COMPONENT" ]; then
        echo "Error: Write permission denied on $LOCAL_REPO_DIR/pool/$COMPONENT."
        exit 1
    fi

    echo "Adding '$deb_file' to the local repository..."
    log "Adding package '$deb_file'."

    sudo cp "$deb_file" "$LOCAL_REPO_DIR/pool/$COMPONENT/"
    sudo chown root:root "$LOCAL_REPO_DIR/pool/$COMPONENT/$(basename "$deb_file")"

    # Update the local repository
    update_local_repo

    echo "Package '$deb_file' added to local repository."
    log "Package '$deb_file' added successfully."
}

# Function to remove a deb file from the local repository and update the repository
remove_from_local_repo() {
    local deb_file="$1"

    # Ensure we have necessary permissions
    if [ ! -w "$LOCAL_REPO_DIR/pool/$COMPONENT" ]; then
        echo "Error: Write permission denied on $LOCAL_REPO_DIR/pool/$COMPONENT."
        exit 1
    fi

    if [ ! -f "$LOCAL_REPO_DIR/pool/$COMPONENT/$deb_file" ]; then
        echo "Package '$deb_file' not found in local repository."
        exit 1
    fi

    echo "Removing '$deb_file' from local repository..."
    log "Removing package '$deb_file'."

    sudo rm "$LOCAL_REPO_DIR/pool/$COMPONENT/$deb_file"

    # Update the local repository
    update_local_repo

    echo "Package '$deb_file' removed from local repository."
    log "Package '$deb_file' removed successfully."
}

# Function to display help
display_help() {
    echo "Usage:"
    echo "  lrep add <deb_file>      Add <deb_file> to local repository"
    echo "  lrep remove <deb_file>   Remove <deb_file> from local repository"
    echo "  lrep list                List all deb files in the local repository"
    echo "  lrep update              Update local repository"
    echo "  lrep help                Display this help message"
    exit 0
}
