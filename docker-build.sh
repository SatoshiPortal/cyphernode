#!/bin/sh

# Must be logged to docker hub:
# docker login -u cyphernode

# Must enable experimental cli features
# "experimental": "enabled" in ~/.docker/config.json

image() {
  local image=$1
  local dir=$2
  local arch=$3

  echo "Building and pushing $image from $dir for $arch using $dockerfile tagging as $v1, $v2 and $v3..."

  docker build -t cyphernode/${image}:${arch}-${v3} -t cyphernode/${image}:${arch}-${v2} -t cyphernode/${image}:${arch}-${v1} ${dir}/. \
  && docker push cyphernode/${image}:${arch}-${v3} \
  && docker push cyphernode/${image}:${arch}-${v2} \
  && docker push cyphernode/${image}:${arch}-${v1}

  return $?
}

manifest() {
  local image=$1

  echo "Creating and pushing manifest for $image for version $v3..."

  docker manifest create cyphernode/${image}:${v3} cyphernode/${image}:${arm_docker}-${v3} cyphernode/${image}:${x86_docker}-${v3} cyphernode/${image}:${aarch64_docker}-${v3} \
  && docker manifest annotate cyphernode/${image}:${v3} cyphernode/${image}:${arm_docker}-${v3} --os linux --arch ${arm_docker} \
  && docker manifest annotate cyphernode/${image}:${v3} cyphernode/${image}:${x86_docker}-${v3} --os linux --arch ${x86_docker} \
  && docker manifest annotate cyphernode/${image}:${v3} cyphernode/${image}:${aarch64_docker}-${v3} --os linux --arch ${aarch64_docker} \
  && docker manifest push -p cyphernode/${image}:${v3}

  [ $? -ne 0 ] && return 1

  echo "Creating and pushing manifest for $image for version $v2..."

  docker manifest create cyphernode/${image}:${v2} cyphernode/${image}:${arm_docker}-${v2} cyphernode/${image}:${x86_docker}-${v2} cyphernode/${image}:${aarch64_docker}-${v2} \
  && docker manifest annotate cyphernode/${image}:${v2} cyphernode/${image}:${arm_docker}-${v2} --os linux --arch ${arm_docker} \
  && docker manifest annotate cyphernode/${image}:${v2} cyphernode/${image}:${x86_docker}-${v2} --os linux --arch ${x86_docker} \
  && docker manifest annotate cyphernode/${image}:${v2} cyphernode/${image}:${aarch64_docker}-${v2} --os linux --arch ${aarch64_docker} \
  && docker manifest push -p cyphernode/${image}:${v2}

  [ $? -ne 0 ] && return 1

  echo "Creating and pushing manifest for $image for version $v1..."

  docker manifest create cyphernode/${image}:${v1} cyphernode/${image}:${arm_docker}-${v1} cyphernode/${image}:${x86_docker}-${v1} cyphernode/${image}:${aarch64_docker}-${v1} \
  && docker manifest annotate cyphernode/${image}:${v1} cyphernode/${image}:${arm_docker}-${v1} --os linux --arch ${arm_docker} \
  && docker manifest annotate cyphernode/${image}:${v1} cyphernode/${image}:${x86_docker}-${v1} --os linux --arch ${x86_docker} \
  && docker manifest annotate cyphernode/${image}:${v1} cyphernode/${image}:${aarch64_docker}-${v1} --os linux --arch ${aarch64_docker} \
  && docker manifest push -p cyphernode/${image}:${v1}

  return $?
}

x86_docker="amd64"
arm_docker="arm"
aarch64_docker="arm64"

# Build amd64 and arm64 first, building for arm will trigger the manifest creation and push on hub

#arch_docker=${arm_docker}
#arch_docker=${aarch64_docker}
arch_docker=${x86_docker}

v1="v0-rc.2"
v2="v0.2-rc.2"
v3="v0.2.2-rc.2"

echo "\nBuilding Cyphernode Core containers\n"
echo "arch_docker=$arch_docker\n"

image "gatekeeper" "api_auth_docker/" ${arch_docker} \
&& image "proxycron" "cron_docker/" ${arch_docker} \
&& image "otsclient" "otsclient_docker/" ${arch_docker} \
&& image "proxy" "proxy_docker/" ${arch_docker} \
&& image "notifier" "notifier_docker/" ${arch_docker} \
&& image "pycoin" "pycoin_docker/" ${arch_docker} \
&& image "cyphernodeconf" "cyphernodeconf_docker/" ${arch_docker}

[ $? -ne 0 ] && echo "Error" && exit 1

[ "${arch_docker}" = "${x86_docker}" ] && echo "Built and pushed ${arch_docker} only" && exit 0
[ "${arch_docker}" = "${aarch64_docker}" ] && echo "Built and pushed ${arch_docker} only" && exit 0
[ "${arch_docker}" = "${arm_docker}" ] && echo "Built and pushed images, now building and pushing manifest for all archs..."

manifest "gatekeeper" \
&& manifest "proxycron" \
&& manifest "otsclient" \
&& manifest "proxy" \
&& manifest "notifier" \
&& manifest "pycoin" \
&& manifest "cyphernodeconf"

[ $? -ne 0 ] && echo "Error" && exit 1

