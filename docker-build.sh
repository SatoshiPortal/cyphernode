#!/bin/sh

# Must be logged to docker hub:
# docker login -u cyphernode

image() {
  local image=$1
  local dir=$2
  local arch=$3
  local dockerfile=${4:-"Dockerfile"}

  echo "Building and pushing $image from $dir for $arch using $dockerfile tagging as $v1, $v2 and $v3..."

  docker build -t cyphernode/${image}:${arch}-${v3} -t cyphernode/${image}:${arch}-${v2} -t cyphernode/${image}:${arch}-${v1} -f ${dir}/${dockerfile} ${dir}/. \
&&  docker push cyphernode/${image}:${arch}-${v3} \
&&  docker push cyphernode/${image}:${arch}-${v2} \
&&  docker push cyphernode/${image}:${arch}-${v1}

  return $?
}

manifest() {
  local image=$1

  echo "Creating and pushing manifest for $image for version $v3..."

  docker manifest create cyphernode/${image}:${v3} cyphernode/${image}:${arm}-${v3} cyphernode/${image}:${x86}-${v3} \
&&  docker manifest annotate cyphernode/${image}:${v3} cyphernode/${image}:${arm}-${v3} --os linux --arch arm \
&&  docker manifest annotate cyphernode/${image}:${v3} cyphernode/${image}:${x86}-${v3} --os linux --arch amd64 \
&&  docker manifest push -p cyphernode/${image}:${v3}

  [ $? -ne 0 ] && return 1

  echo "Creating and pushing manifest for $image for version $v2..."

  docker manifest create cyphernode/${image}:${v2} cyphernode/${image}:${arm}-${v2} cyphernode/${image}:${x86}-${v2} \
&&  docker manifest annotate cyphernode/${image}:${v2} cyphernode/${image}:${arm}-${v2} --os linux --arch arm \
&&  docker manifest annotate cyphernode/${image}:${v2} cyphernode/${image}:${x86}-${v2} --os linux --arch amd64 \
&&  docker manifest push -p cyphernode/${image}:${v2}

  [ $? -ne 0 ] && return 1

  echo "Creating and pushing manifest for $image for version $v1..."

  docker manifest create cyphernode/${image}:${v1} cyphernode/${image}:${arm}-${v1} cyphernode/${image}:${x86}-${v1} \
&&  docker manifest annotate cyphernode/${image}:${v1} cyphernode/${image}:${arm}-${v1} --os linux --arch arm \
&&  docker manifest annotate cyphernode/${image}:${v1} cyphernode/${image}:${x86}-${v1} --os linux --arch amd64 \
&&  docker manifest push -p cyphernode/${image}:${v1}

  return $?

}

image_dockers() {
  local image=$1
  local dir=$2
  local v=$3
  local arch=$4
  local dockerfile=${5:-"Dockerfile"}

  echo "Building and pushing $image from $dir for $arch using $dockerfile tagging as $v..."

  docker build -t cyphernode/${image}:${arch}-${v} -f ${dir}/${dockerfile} ${dir}/. \
&&  docker push cyphernode/${image}:${arch}-${v}

  return $?

}

manifest_dockers() {
  local image=$1
  local v=$2

  echo "Creating and pushing manifest for $image for version $v..."

  docker manifest create cyphernode/${image}:${v} cyphernode/${image}:${arm}-${v} cyphernode/${image}:${x86}-${v} \
&&  docker manifest annotate cyphernode/${image}:${v} cyphernode/${image}:${arm}-${v} --os linux --arch arm \
&&  docker manifest annotate cyphernode/${image}:${v} cyphernode/${image}:${x86}-${v} --os linux --arch amd64 \
&&  docker manifest push -p cyphernode/${image}:${v}

  return $?

}

x86="amd64"
arm="arm32v6"

#arch=${arm}
arch=${x86}

v1="v0-rc.1"
v2="v0.2-rc.1"
v3="v0.2.0-rc.1"

echo "arch=$arch"

image "gatekeeper" "api_auth_docker/" ${arch} \
&& image "proxycron" "cron_docker/" ${arch} \
&& image "otsclient" "otsclient_docker/" ${arch} \
&& image "proxy" "proxy_docker/" ${arch} "Dockerfile.${arch}" \
&& image "pycoin" "pycoin_docker/" ${arch} \
&& image "cyphernodeconf" "install/" ${arch}

[ $? -ne 0 ] && echo "Error" && return 1

[ "${arch}" = "${x86}" ] && echo "Built and pushed amd64 only" && return 0

manifest "gatekeeper" \
&& manifest "proxycron" \
&& manifest "otsclient" \
&& manifest "proxy" \
&& manifest "pycoin" \
&& manifest "cyphernodeconf"

[ $? -ne 0 ] && echo "Error" && return 1

image_dockers "clightning" "../dockers/c-lightning 0.6.2" ${arch} "Dockerfile.${arch}" \
&& image_dockers "bitcoin" "../dockers/bitcoin-core 0.17.0" ${arch} "Dockerfile.${arch}"

[ $? -ne 0 ] && echo "Error" && return 1

manifest_dockers "clightning" "0.6.2" \
&& manifest_dockers "bitcoin" "0.17.0"

[ $? -ne 0 ] && echo "Error" && return 1
