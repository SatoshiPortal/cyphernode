FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends curl jq && rm -rf /var/lib/apt/lists/*

WORKDIR /sp

COPY app/package*.json ./
RUN npm ci --omit=dev

COPY app/ .
RUN chmod +x startsp.sh && mkdir -p /sp/data && chown node:node /sp/data

USER node

CMD ["./startsp.sh"]
