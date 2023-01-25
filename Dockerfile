FROM node:18

COPY package-lock.json .
COPY package.json .

RUN npm install 

COPY . .
RUN npm run compile
# Explicitly specify entrypoint in docker compose
