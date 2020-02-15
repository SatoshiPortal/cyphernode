FROM python:3.8.1-alpine

WORKDIR /

RUN \
  mkdir /static && \
  mkdir /data && \
  apk --no-cache add --update \
    alpine-sdk \
    git \
    bash \
    libusb-dev \
    zlib \
    zlib-dev \
    openssl \
    openssl-dev \
    hidapi-dev \
    libffi-dev \
    udev \
    eudev-dev \
    libjpeg \
    jpeg-dev \
  #  libfreetype6-dev \
  #  liblcms2-dev \
  #  libtiff-dev \
  #  libraqm-dev \
  #  libimagequant-dev \
    su-exec && \
    git clone --recursive https://github.com/Coldcard/ck-bunker.git && \
      cd ck-bunker && \
      pip install -r requirements.txt && \
      pip install --editable .

ENV PATH=${PATH}:/ck-bunker

ENTRYPOINT ["su-exec"]
