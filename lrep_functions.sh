#!/bin/sh

# /usr/lib/lrep/lrep_functions.sh
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

# Function to check for read permission
check_read_permission() {
    if [ ! -r "$1" ]; then
        echo "Error: Read permission denied on '$1'."
        exit 1
    fi
}

# Function to check for write permission
check_write_permission() {
    if [ ! -w "$1" ]; then
        echo "Error: Write permission denied on '$1'."
        exit 1
    fi
}

# Logging function
log() {
    check_write_permission "$LOG_FILE"
    message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE" >/dev/null
}

# Function to update the local repository
update_local_repo() {
    log "Starting repository update."

    # Ensure we have necessary permissions
    check_write_permission "$LOCAL_REPO_DIR"
    check_read_permission "$PRIVATE_KEY_DIR"

    echo "Updating local repository..."

    # Generate the Packages.gz file
    (cd "$LOCAL_REPO_DIR" && \
        dpkg-scanpackages "pool/$COMPONENT" /dev/null | \
        tee "dists/$DIST_NAME/$COMPONENT/binary-$ARCH/Packages" | \
        gzip -9c | tee "dists/$DIST_NAME/$COMPONENT/binary-$ARCH/Packages.gz" >/dev/null)

    # Generate the Release file
    apt-ftparchive  \
        -o APT::FTPArchive::Release::Origin="Local" \
        -o APT::FTPArchive::Release::Label="Local" \
        -o APT::FTPArchive::Release::Suite="$DIST_NAME" \
        -o APT::FTPArchive::Release::Codename="$DIST_NAME" \
        -o APT::FTPArchive::Release::Architectures="$ARCH" \
        -o APT::FTPArchive::Release::Components="$COMPONENT" \
        release "$LOCAL_REPO_DIR/dists/$DIST_NAME" | tee "$LOCAL_REPO_DIR/dists/$DIST_NAME/Release" >/dev/null

    # Sign the Release file to create Release.gpg and InRelease
    gpg --homedir "$PRIVATE_KEY_DIR" --default-key 'LocalRepositoryKey' --batch --yes --detach-sign \
        --armor --output "$LOCAL_REPO_DIR/dists/$DIST_NAME/Release.gpg" "$LOCAL_REPO_DIR/dists/$DIST_NAME/Release"
    gpg --homedir "$PRIVATE_KEY_DIR" --default-key 'LocalRepositoryKey' --batch --yes --clearsign \
        --output "$LOCAL_REPO_DIR/dists/$DIST_NAME/InRelease" "$LOCAL_REPO_DIR/dists/$DIST_NAME/Release"

    echo "Local repository updated successfully."
    log "Repository update completed."
}

# Function to list all packages in the local repository
list_local_repo() {
    echo "Packages in local repository:"
    if [ -d "$LOCAL_REPO_DIR/pool/$COMPONENT" ]; then
        found=0
        for deb_file in "$LOCAL_REPO_DIR/pool/$COMPONENT/"*.deb; do
            # Skip if no .deb files are found
            if [ ! -e "$deb_file" ]; then
                continue
            fi
            found=1
            deb_filename=$(basename "$deb_file")
            # Extract package name and version from the .deb file
            pkg_name=$(dpkg-deb --field "$deb_file" Package)
            pkg_version=$(dpkg-deb --field "$deb_file" Version)
            # Get package status and installed version
            pkg_status=$(dpkg-query -W -f='${Status}' "$pkg_name" 2>/dev/null)
            installed_version=$(dpkg-query -W -f='${Version}' "$pkg_name" 2>/dev/null)
            # Determine the package status
            if [ "$installed_version" = "$pkg_version" ]; then
                if echo "$pkg_status" | grep -q '^deinstall ok config-files$'; then
                    status="${YELLOW}residual-config${RESET}"
                else
                    status="${GREEN}installed${RESET}"
                fi
            else
                status="${RED}not installed${RESET}"
            fi
            echo "$deb_filename - $status"
        done
        if [ "$found" -eq 0 ]; then
            echo "No packages found in local repository."
        fi
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
    check_write_permission "$LOCAL_REPO_DIR/pool/$COMPONENT"

    echo "Adding '$deb_file' to the local repository..."
    log "Adding package '$deb_file'."

    cp "$deb_file" "$LOCAL_REPO_DIR/pool/$COMPONENT/"
    #chown root:root "$LOCAL_REPO_DIR/pool/$COMPONENT/$(basename "$deb_file")"

    echo "Package '$deb_file' added to local repository."
    log "Package '$deb_file' added successfully."
}

# Function to remove a deb file from the local repository and update the repository
remove_from_local_repo() {
    local deb_file="$1"

    # Ensure we have necessary permissions
    check_write_permission "$LOCAL_REPO_DIR/pool/$COMPONENT"

    if [ ! -f "$LOCAL_REPO_DIR/pool/$COMPONENT/$deb_file" ]; then
        echo "Package '$deb_file' not found in local repository."
        exit 1
    fi

    echo "Removing '$deb_file' from local repository..."
    log "Removing package '$deb_file'."

    rm "$LOCAL_REPO_DIR/pool/$COMPONENT/$deb_file"

    echo "Package '$deb_file' removed from local repository."
    log "Package '$deb_file' removed successfully."
}

# Function to export all deb files from the local repository to a specified directory
export_local_repo() {
    local output_dir="$1"

    # Ensure we have necessary permissions to read from the local repository
    check_read_permission "$LOCAL_REPO_DIR/pool/$COMPONENT"

    # Check if output directory exists
    if [ ! -d "$output_dir" ]; then
        echo "Output directory '$output_dir' does not exist."
        read -p "Do you want to create it? [y/N]: " answer
        case "$answer" in
            [Yy]*)
                mkdir -p "$output_dir"
                ;;
            *)
                echo "Aborting export."
                exit 1
                ;;
        esac
    fi

    # Ensure we have necessary permissions to write to output directory
    check_write_permission "$output_dir"

    echo "Exporting packages to '$output_dir'..."

    # Copy all .deb files from the repository to the output directory
    if [ -d "$LOCAL_REPO_DIR/pool/$COMPONENT" ]; then
        found=0
        for deb_file in "$LOCAL_REPO_DIR/pool/$COMPONENT/"*.deb; do
            if [ ! -e "$deb_file" ]; then
                continue
            fi
            found=1
            cp "$deb_file" "$output_dir/"
        done
        if [ "$found" -eq 0 ]; then
            echo "No packages found in local repository."
        else
            echo "Packages exported successfully."
        fi
    else
        echo "No packages found in local repository."
    fi
}

# Function to display help
display_help() {
    echo "Usage:"
    echo "  lrep add <deb_files>...      Add one or more .deb files to local repository"
    echo "  lrep remove <deb_files>...   Remove one or more .deb files from local repository"
    echo "  lrep list                    List packages with color-coded installation status"
    echo "  lrep update                  Update local repository"
    echo "  lrep export <output_dir>     Export all packages to <output_dir>"
    echo "  lrep help                    Display this help message"
    exit 0
}
