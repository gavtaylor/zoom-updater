# zoom-updater

A small standalone script that checks for and installs the latest
[Zoom](https://zoom.us/download) desktop client release on Linux.

## Why this exists

Zoom does not ship a dnf/apt repo or an in-app updater for the Linux build,
so updates have to be downloaded and installed by hand. This script fills
that gap: it checks the latest version Zoom is currently serving, compares
it to what's installed, and installs the update if one is available.

## Requirements

- `curl`
- One of:
  - `dnf` or `yum` + `rpm` (Fedora, RHEL, openSUSE, etc.)
  - `apt-get` + `dpkg` (Debian, Ubuntu, etc.)
- `sudo` access to install packages

## Installation

Clone this repo, or download the script directly:

```bash
curl -fsSL https://raw.githubusercontent.com/gavtaylor/zoom-updater/main/update-zoom.sh -o ~/.local/bin/update-zoom
chmod +x ~/.local/bin/update-zoom
```

Make sure `~/.local/bin` is on your `PATH`. Then run it whenever you want to check for updates:

```bash
update-zoom
```

### Using it as a shell function instead

If you'd rather source it as a bash function (e.g. from your `.bashrc` or a
`bashrc.d/` snippet), download the script somewhere permanent and source it:

```bash
curl -fsSL https://raw.githubusercontent.com/gavtaylor/zoom-updater/main/update-zoom.sh -o ~/.bashrc.d/update-zoom.sh
```

```bash
# in .bashrc
for f in ~/.bashrc.d/*.sh; do source "$f"; done
```

The script detects whether it's being run directly or sourced, and only
auto-executes when run directly, so sourcing it just makes the
`update-zoom` function available in your shell without running it.

## What it does

1. Reads the currently installed version (`rpm -q` or `dpkg-query`).
2. Zoom doesn't publish a version API or release feed. Its "latest" download
   link (`zoom.us/client/latest/...`) 302-redirects to a CDN URL that embeds
   the version number, so the script sends a `HEAD` request and reads that
   redirect to learn the latest version without downloading the ~300MB
   package.
3. If already up to date, exits with no changes.
4. If an update is available, prompts for `sudo` up front (before the
   download, not after), downloads the correct package for your package
   manager, and installs it.
5. Verifies the installed version actually matches the expected version
   after install, this catches package managers reporting a false "success"
   on a no-op transaction.
6. Warns (without blocking) if the Zoom process is still running, since
   closing the window only minimises it to the tray on most desktop
   environments. It needs to be fully quit and relaunched to pick up the new
   version.

## Known limitations

- **No checksum/signature verification.** Zoom does not publish a
  `SHA256SUMS` file or signature alongside these installers. The script
  downloads over HTTPS directly from Zoom's own CDN but cannot
  cryptographically verify the package contents beyond that.
- Only supports `x86_64`/`amd64` builds. Open an issue/PR if you need `arm64`
  support.
- Relies on the current `zoom.us/client/latest/...` → CDN redirect
  behaviour to detect versions. If Zoom changes this scheme, version
  detection will start failing loudly (rather than silently installing the
  wrong thing) and the script will need a small update.

## Related projects

Sibling script for another Linux app Microsoft doesn't provide a package
manager or in-app update path for:
[github-copilot-updater](https://github.com/gavtaylor/github-copilot-updater).

## Contributing

This is intentionally kept small and dependency-light. PRs welcome for genuine
bug fixes or missing distro support, please avoid scope creep into a general
Zoom config manager, that's a different project.

## License

MIT, see [LICENSE](LICENSE).
