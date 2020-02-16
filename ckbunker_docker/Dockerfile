FROM python:3.8.1-alpine

WORKDIR /

RUN \
  mkdir /static && \
  mkdir /data && \
  apk --no-cache add --update \
      bash \
      tor \
      libusb \
      zlib \
      openssl \
      hidapi \
      libffi\
      udev \
      eudev \
      freetype \
      su-exec \
      usbutils \
      libjpeg && \
  apk --no-cache add --update --virtual .build-deps \
    git \
    alpine-sdk \
    libusb-dev \
    zlib-dev \
    openssl-dev \
    hidapi-dev \
    libffi-dev \
    eudev-dev \
    freetype-dev \
    jpeg-dev && \
  #  libfreetype6-dev \
  #  liblcms2-dev \
  #  libtiff-dev \
  #  libraqm-dev \
  #  libimagequant-dev \
    git clone --recursive https://github.com/Coldcard/ck-bunker.git && \
      cd ck-bunker && \
      pip install -r requirements.txt && \
      pip install --editable . && \
      ln -s /sys/bus /dev/bus && \
  apk del .build-deps

ENV PATH=${PATH}:/ck-bunker

COPY entrypoint.sh /
WORKDIR /ck-bunker

ENTRYPOINT ["/entrypoint.sh"]
