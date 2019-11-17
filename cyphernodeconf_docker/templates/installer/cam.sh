#!/bin/sh

current_path="$(cd "$(dirname "$0")" >/dev/null && pwd)"
# !!!!!!!!! DO NOT INCLUDE APPS WITHOUT REVIEW !!!!!!!!!!

docker run -e CYPHERAPPS_INSTALL_DIR=/apps -v "$current_path"/apps:/apps -v "$current_path":/data --rm cyphernode/cam:<%= cam_version %> $*
