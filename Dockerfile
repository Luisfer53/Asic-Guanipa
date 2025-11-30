FROM node:22-alpine

RUN apk add --no-cache postgresql-client bash

WORKDIR /app

COPY . /app

RUN cd /app && \
  npm install --omit=dev

ENTRYPOINT ["bash"]
CMD ["/app/bin/server"]

