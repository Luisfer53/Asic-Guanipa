FROM node:22-alpine

RUN apk add --no-cache postgresql-client

COPY . /app

RUN cd /app && \
  npm install --omit=dev

CMD ["/app/bin/server"]

