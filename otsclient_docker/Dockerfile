FROM node:11.1-alpine

RUN apk add --update --no-cache \
    git \
    jq \
    su-exec \
    socat \
 && yarn global add javascript-opentimestamps

WORKDIR /script

COPY script/otsclient.sh /script/otsclient.sh
COPY script/requesthandler.sh /script/requesthandler.sh
COPY script/responsetoclient.sh /script/responsetoclient.sh
COPY script/startotsclient.sh /script/startotsclient.sh
COPY script/trace.sh /script/trace.sh
COPY script/monitoring.sh /script/monitoring.sh

RUN chmod +x /script/startotsclient.sh /script/requesthandler.sh

ENTRYPOINT ["su-exec"]

# docker build -t otsclient-js .
# docker run -it --rm --name otsclient -v /home/debian/otsfiles:/otsfiles otsclient-js `id -u cyphernode`:`id -g cyphernode` ash

# ots-cli.js stamp -d 1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7
# ots-cli.js verify -d 1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7 1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7.ots
# ots-cli.js info 1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7.ots
# ots-cli.js upgrade 1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7.ots
