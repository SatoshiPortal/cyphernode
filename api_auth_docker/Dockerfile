FROM nginx:alpine

RUN apk add --update --no-cache \
		bash \
    git \
    openssl \
    fcgiwrap \
    spawn-fcgi \
    curl \
    jq \
    su-exec

COPY auth.sh /etc/nginx/conf.d
COPY default-ssl.conf /etc/nginx/conf.d/default.conf
COPY statuspage.html /etc/nginx/conf.d/status
COPY entrypoint.sh entrypoint.sh
COPY trace.sh /etc/nginx/conf.d
COPY tests.sh /etc/nginx/conf.d

RUN chmod +x /etc/nginx/conf.d/auth.sh entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
