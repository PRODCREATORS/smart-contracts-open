#! /bin/bash
set -e
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
echo "Download tricypto pool abi (address: 0xd51a44d3fae010294c616388b506acda1bfaae46)..."
curl http://api.etherscan.io/api\?module\=contract\&action\=getabi\&address\=0xd51a44d3fae010294c616388b506acda1bfaae46\&format\=raw -H "User-Agent: Chrome" > /tmp/tricrypto_pool_abi.json
echo "Genrating interface..."
cat /tmp/tricrypto_pool_abi.json | npx abi-to-sol ITricryptoPool > $PROJECT_ROOT/contracts/interfaces/thirdparty/ITricryptoPool.sol
echo "Done."
