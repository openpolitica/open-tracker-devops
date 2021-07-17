FROM node:12-alpine
WORKDIR /usr/src/app
COPY package*.json ./

RUN npm install
RUN npm ci --only=production

COPY . .
EXPOSE 3000

ENV NODE_ENV=production

CMD [ "node", "bin/www" ]
