. ./install_docker.sh
. ./install_lunanode.sh

install() {
  . ../data/installer/config.sh
  if [[ ''$INSTALLER_MODE == 'none' ]]; then
    echo "Skipping installation phase"
  elif [[ ''$INSTALLER_MODE == 'docker' ]]; then
    install_docker
  elif [[ ''$INSTALLER_MODE == 'lunanode' ]]; then
    install_lunanode
  fi
}