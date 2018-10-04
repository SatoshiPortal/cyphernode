FROM nginx:alpine

RUN apk add --update --no-cache \
    git \
    openssl \
    fcgiwrap \
    spawn-fcgi \
    curl \
    jq

COPY auth.sh /etc/nginx/conf.d
COPY default-ssl.conf /etc/nginx/conf.d/default.conf
COPY entrypoint.sh entrypoint.sh
COPY keys.properties /etc/nginx/conf.d
COPY trace.sh /etc/nginx/conf.d

RUN chmod +x /etc/nginx/conf.d/auth.sh entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
