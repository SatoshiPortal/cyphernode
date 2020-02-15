FROM python:3.8.1-slim-buster

RUN apt-get update && apt-get install -y \
  build-essential \
  libusb-1.0-0-dev \
  libhidapi-dev \
  libffi-dev \
  libudev-dev \
  libimagequant-dev \
  libjpeg-dev \
  libfreetype6-dev \
  liblcms2-dev \
  libtiff-dev \
  libraqm-dev \
  openssl \
  git \
  gosu \
  bash
# libimagequant libfreetype littlecms libtiff libraqm
WORKDIR /

RUN git clone --recursive https://github.com/Coldcard/ck-bunker.git && \
  cd ck-bunker && \
  pip install -r requirements.txt && \
  pip install --editable .

ENV PATH=${PATH}:/ck-bunker

RUN mkdir /static

ENTRYPOINT ["gosu"]
