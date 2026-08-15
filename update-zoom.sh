#!/usr/bin/env bash
#
# update-zoom.sh
#
# Checks for and installs the latest Zoom desktop client release on Linux
# (rpm or deb), since Zoom does not ship a dnf/apt repo or an in-app updater
# for the Linux build.
#
# Usage:
#   ./update-zoom.sh
#
# Requirements: curl, and either dnf/yum (rpm) or apt/dpkg (deb).

set -o pipefail

DOWNLOAD_HOST="https://zoom.us/client/latest"

update-zoom() {
    local current latest pkg_file pkg_mgr pkg_name asset_ext download_url resolved_url zoom_pid installed

    if command -v rpm >/dev/null 2>&1 && (command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1); then
        pkg_mgr="rpm"
        asset_ext="x86_64.rpm"
        pkg_name="zoom"
    elif command -v dpkg >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
        pkg_mgr="deb"
        asset_ext="amd64.deb"
        pkg_name="zoom"
    else
        echo "✗ Unsupported system: no dnf/yum (rpm) or apt/dpkg (deb) found."
        return 1
    fi

    pkg_file=$(mktemp --suffix=".${asset_ext##*.}")
    trap 'rm -f "$pkg_file"' RETURN

    if [[ "$pkg_mgr" == "rpm" ]]; then
        current=$(rpm -q --qf '%{VERSION}\n' "$pkg_name" 2>/dev/null || true)
    else
        current=$(dpkg-query -W -f='${Version}\n' "$pkg_name" 2>/dev/null | sed 's/-.*//' || true)
    fi

    download_url="${DOWNLOAD_HOST}/zoom_${asset_ext}"

    # Zoom doesn't publish a version API. The "latest" download link 302s to a
    # CDN URL that embeds the version (…/prod/<version>/zoom_x86_64.rpm), so a
    # HEAD request is enough to learn the latest version without pulling the
    # ~300MB package.
    resolved_url=$(curl -fsSI "$download_url" -o /dev/null -w '%{redirect_url}')

    if [[ -z "$resolved_url" ]]; then
        echo "✗ Unable to determine latest Zoom version (zoom.us unreachable, or redirect format changed)."
        return 1
    fi

    latest=$(echo "$resolved_url" | grep -oP '/prod/\K[0-9.]+(?=/)')

    if [[ -z "$latest" ]]; then
        echo "✗ Unable to parse latest Zoom version from ${resolved_url}"
        return 1
    fi

    if [[ "$current" == "$latest" ]]; then
        echo "✓ Zoom is already up to date (${current})"
        return 0
    fi

    echo "Updating Zoom: ${current:-not installed} → ${latest}"

    # Prompt for sudo up front, before the ~300MB download, not after.
    if ! sudo -v; then
        echo "✗ sudo authentication failed."
        return 1
    fi

    if ! curl -fsSL "$resolved_url" -o "$pkg_file"; then
        echo "✗ Download failed: ${resolved_url}"
        return 1
    fi

    if [[ "$pkg_mgr" == "rpm" ]]; then
        if ! sudo dnf install -y "$pkg_file"; then
            echo "✗ Installation failed."
            return 1
        fi
        installed=$(rpm -q --qf '%{VERSION}\n' "$pkg_name" 2>/dev/null || true)
    else
        if ! sudo apt-get install -y "$pkg_file"; then
            echo "✗ Installation failed."
            return 1
        fi
        installed=$(dpkg-query -W -f='${Version}\n' "$pkg_name" 2>/dev/null | sed 's/-.*//' || true)
    fi

    if [[ "$installed" != "$latest" ]]; then
        echo "✗ Package manager reported success but installed version is ${installed:-none}, expected ${latest}."
        return 1
    fi

    echo "✓ Updated to ${latest}"

    zoom_pid=$(pgrep -x zoom 2>/dev/null || true)
    if [[ -n "$zoom_pid" ]]; then
        echo "⚠ Zoom is still running (pid ${zoom_pid})."
        echo "  Closing the window only minimises it to the tray, it will keep running ${current}."
        echo "  Fully quit it (tray icon → Quit) and relaunch to pick up ${latest}."
    fi
}

# Allow the script to be sourced (to reuse the function directly) or run
# standalone (to execute immediately).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    update-zoom "$@"
fi
