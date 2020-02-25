FROM python:3.8-slim-buster

WORKDIR /

RUN \
  mkdir /static && \
  mkdir /data && \
  apt-get update && apt-get install -y \
      bash \
      tor \
      libusb-1.0-0 \
      zlib1g \
      openssl \
      libhidapi-dev \
      libffi6\
      udev \
      libfreetype6 \
      gosu \
      usbutils \
      libjpeg-dev \
      git \
      libudev-dev \
      build-essential \
      libusb-1.0-0-dev \
      zlib1g-dev \
      libffi-dev \
      libssl-dev \
      libfreetype6-dev && \
  #  libfreetype6-dev \
  #  liblcms2-dev \
  #  libtiff-dev \
  #  libraqm-dev \
  #  libimagequant-dev \
    git clone --recursive https://github.com/Coldcard/ck-bunker.git && \
      cd ck-bunker && \
      pip install -r requirements.txt && \
      pip install --editable . && \
  apt-get remove --purge -y \
      git \
      build-essential \
      libudev-dev \
      libusb-1.0-0-dev \
      zlib1g-dev \
      libffi-dev \
      libssl-dev \
      libfreetype6-dev && \
      apt-get autoremove -y && \
      rm -rf /var/lib/apt/lists/*

ENV PATH=${PATH}:/ck-bunker

COPY entrypoint.sh /
WORKDIR /ck-bunker

RUN echo "Log notice file /var/log/tor/notices.log" >> /etc/tor/torrc && \
    echo "DataDirectory /var/lib/tor" >> /etc/tor/torrc && \
    echo "ControlPort 9051" >> /etc/tor/torrc

ENTRYPOINT ["/entrypoint.sh"]
