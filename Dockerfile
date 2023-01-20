FROM node:18

COPY package-lock.json .
COPY package.json .

RUN npm install 

COPY . .
RUN npm run compile

CMD ["npm", "run", "update-prices"]