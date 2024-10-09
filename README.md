# lrep - Local Debian Repository Management Tool

**lrep** is a command-line tool designed to help you manage a local Debian
repository on your system. It allows you to easily add, remove, list, and
update Debian packages in your local repository. This tool is particularly
useful for system administrators and developers who need to manage custom
packages or maintain a local mirror of Debian packages.

## Features

- **Add** Debian packages to your local repository.
- **Remove** packages from your local repository.
- **List** all packages currently in your local repository.
- **Update** the repository metadata after adding or removing packages.
- **Bash and Zsh Completion** for enhanced command-line experience.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Adding a Package](#adding-a-package)
  - [Removing a Package](#removing-a-package)
  - [Listing Packages](#listing-packages)
  - [Updating the Repository](#updating-the-repository)
- [Completion Scripts](#completion-scripts)
  - [Bash Completion](#bash-completion)
  - [Zsh Completion](#zsh-completion)
- [Uninstallation](#uninstallation)
- [License](#license)
- [Contributing](#contributing)

## Prerequisites

- **Operating System**: Debian-based distributions (Debian, Ubuntu, etc.)
- **Dependencies**:
  - `apt-utils`
  - `dpkg-dev`
  - `gpg`
  - `bash` or `zsh` (for completion scripts)
- **Tools for Building from Source** (if not installing from a package):
  - `git`
  - `fakeroot`
  - `dpkg-deb`
  - `envsubst` (from the `gettext` package)

## Installation

### Using the Debian Package

You can install `lrep` using the provided Debian package.

1. **Download the Package**

   Download the latest `.deb` package from the
   [Releases](https://github.com/jpasquier/lrep/releases) page.

2. **Install the Package**

   ```bash
   sudo dpkg -i lrep_<version>_all.deb
   ```

   Replace `<version>` with the actual version number of the package.

3. **Fix Dependencies**

   If you encounter dependency issues, run:

   ```bash
   sudo apt-get install -f
   ```

### Building frome Source (first method)

1. **Build the Package**

   ```bash
   curl -L https://raw.githubusercontent.com/jpasquier/lrep/refs/heads/main/build-lrep-deb | bash
   ```

   This will generate a `.deb` package in the current directory.

3. **Install the Package**

   ```bash
   sudo dpkg -i lrep_<version>_all.deb
   ```

### Building from Source (second method)

1. **Clone the Repository**

   ```bash
   git clone https://github.com/jpasquier/lrep.git
   ```

2. **Optional: Adapt the configuration file to your needs**

   Modify `lrep.conf` to your needs.

3. **Build the Package**

   Navigate to the cloned directory and run the build script:

   ```bash
   cd lrep
   ./build-lrep-deb --local
   ```

   This will generate a `.deb` package in the current directory.

4. **Install the Package**

   ```bash
   sudo dpkg -i lrep_<version>_all.deb
   ```

## Configuration

The configuration file for `lrep` is located at `/etc/lrep.conf`. This file
contains various settings that control the behavior of the tool.

**Default Configuration:**

```bash
# /etc/lrep.conf
# Configuration file for lrep

# Automatically detect architecture
ARCH=${ARCH:-$(dpkg --print-architecture)}

# Repository settings
DIST_NAME=${DIST_NAME:-stable}
COMPONENT=${COMPONENT:-main}
LOCAL_REPO_DIR=${LOCAL_REPO_DIR:-/srv/local-repository}

# APT sources list
APT_SOURCES_LIST=${APT_SOURCES_LIST:-/etc/apt/sources.list.d/local-repository.list}

# GPG key directories
PRIVATE_KEY_DIR=${PRIVATE_KEY_DIR:-/usr/local/share/local-repository/private-key}
PUBLIC_KEY_DIR=${PUBLIC_KEY_DIR:-/usr/share/keyrings}
PUBLIC_KEY_FILE=${PUBLIC_KEY_FILE:-$PUBLIC_KEY_DIR/local-repository.gpg}

# Log file
LOG_FILE=${LOG_FILE:-/var/log/lrep.log}
```

**Note:** If you modify the configuration, you may need to rebuild or update
your repository for the changes to take effect.

## Usage

After installation, you can use the `lrep` command to manage your local
repository.

**Syntax:**

```bash
lrep <command> [arguments]
```

**Available Commands:**

- `add <deb_files>...`: Add one or more `.deb` packages to the local repository.
- `remove <deb_files>...`: Remove one or more packages from the local repository.
- `list`: List all packages in the local repository.
- `update`: Update the repository metadata.
- `export <output_dir>`: Export all packages to the specified directory.
- `help`: Display the help message.

**Note:**

In the default configuration, the commands `add`, `remove`, and `update` have to be run as root.

### Adding a Package

To add one or more packages to your local repository:

```bash
lrep add package1.deb package2.deb
```

You can also use wildcards:

```bash
lrep add *.deb
```

This command copies the specified `.deb` files to the repository, updates the
metadata, and signs the repository.

### Removing a Package

To remove one or more packages from your local repository:

```bash
lrep remove package1.deb package2.deb
```

This command removes the specified packages from the repository and updates the
metadata.

*Note:* To remove all packages from the repository, you can use:

```bash
lrep remove $(lrep list | awk '{print $1}' | grep '.deb')
```

### Listing Packages

To list all packages in your local repository:

```bash
lrep list
```

This command displays all `.deb` files currently in your repository.

### Updating the Repository

To manually update the repository metadata:

```bash
lrep update
```

This is useful if you make changes to the repository directory outside of
`lrep`.

### Exporting Packages

To export all packages from your local repository to a specific directory:

```bash
lrep export /path/to/output_dir
```

If the directory does not exist, you will be prompted to create it.

## Completion Scripts

`lrep` comes with command-line completion scripts for both Bash and Zsh,
enhancing your command-line experience by providing suggestions and
auto-completion for commands and package names.

### Bash Completion

The Bash completion script is installed to `/etc/bash_completion.d/lrep` and
should be loaded automatically.

If it's not working, you can manually source it:

```bash
source /etc/bash_completion.d/lrep
```

### Zsh Completion

The Zsh completion script is installed to
`/usr/share/zsh/vendor-completions/_lrep`.

To ensure it is loaded, make sure the following is in your `~/.zshrc`:

```zsh
autoload -Uz compinit
compinit
```

You may need to start a new shell session or run `exec zsh` to reload your
configuration.

## Uninstallation

To uninstall `lrep`, you can use the following command:

```bash
sudo dpkg --purge lrep
```

**Note:** This will remove `lrep` and delete your local repository data,
including the repository directory and GPG keys.

## License

This project is licensed under the [MIT License](LICENSE).

## Contributing

Contributions are welcome! Please open an issue or submit a pull request on
GitHub.

1. **Fork the Repository**
2. **Create a Feature Branch**

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Commit Your Changes**
4. **Push to Your Fork**

   ```bash
   git push origin feature/your-feature-name
   ```

5. **Open a Pull Request**

---

If you have any questions or need further assistance, please feel free to open
an issue on GitHub.
