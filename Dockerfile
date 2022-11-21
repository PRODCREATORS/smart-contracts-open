FROM node:16
WORKDIR /app
COPY package.json .
COPY package-lock.json .
RUN npm ci
COPY . .
EXPOSE 8545
CMD ["npx", "-y", "hardhat", "node", "--fork", "https://eth-mainnet.g.alchemy.com/v2/Yi_2dFpsDEGKLVcdZRcPtMTh7FX9Bkco", "--verbose"]
