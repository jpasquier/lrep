# Bash completion script for lrep

# Check if lrep is installed
which lrep >/dev/null 2>&1 || return

_lrep() {
    local cur prev commands packages
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Source configuration variables
    if [ -f "/etc/lrep.conf" ]; then
        . /etc/lrep.conf
    else
        # Default values if configuration file is missing
        LOCAL_REPO_DIR="/srv/local-repository"
        COMPONENT="main"
    fi

    # Define the available commands
    commands="add remove list update help"

    # Handle command completion
    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=( $(compgen -W "${commands}" -- "${cur}") )
        return 0
    fi

    # Handle subcommand arguments
    case "${COMP_WORDS[1]}" in
        remove)
            # Suggest package names from the local repository
            local repo_dir="${LOCAL_REPO_DIR}/pool/${COMPONENT}"
            if [ -d "$repo_dir" ]; then
                packages=$(ls "$repo_dir"/*.deb 2>/dev/null | xargs -n1 basename)
                COMPREPLY=( $(compgen -W "${packages}" -- "${cur}") )
            fi
            ;;
        add)
            # Suggest .deb files in the current directory
            COMPREPLY=( $(compgen -f -X '!*.deb' -- "${cur}") )
            ;;
        *)
            ;;
    esac
    return 0
}

# Register the completion function for lrep
complete -F _lrep lrep
