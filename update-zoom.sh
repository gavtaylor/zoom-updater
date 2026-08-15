#!/usr/bin/env bash

function update-zoom {
  wget https://zoom.us/client/latest/zoom_x86_64.rpm -P /tmp
  sudo dnf localinstall /tmp/zoom_x86_64.rpm
}
