FROM nginx:alpine

RUN apk add --update --no-cache \
		bash \
    git \
    openssl \
    fcgiwrap \
    spawn-fcgi \
    curl \
    jq

COPY auth.sh /etc/nginx/conf.d/
COPY default.conf /etc/nginx/conf.d/default.conf
COPY entrypoint.sh entrypoint.sh
COPY trace.sh /etc/nginx/conf.d/
COPY tests.sh /etc/nginx/conf.d/

RUN chmod +x /etc/nginx/conf.d/auth.sh entrypoint.sh

RUN touch /var/log/gatekeeper.log
RUN chmod a+rw /var/log/gatekeeper.log

ENTRYPOINT ["./entrypoint.sh"]
