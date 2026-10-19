FROM node:22-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install --omit=dev

COPY . /app

ENTRYPOINT ["sh"]
CMD ["/app/bin/server"]
