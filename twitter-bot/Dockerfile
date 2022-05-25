FROM node:18-alpine
WORKDIR /usr/src/app
COPY package*.json ./

RUN npm install
RUN npm ci --only=production

COPY . .

ENV NODE_ENV=production

CMD [ "node", "index.js" ]
