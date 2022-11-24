#! /bin/bash
set -e
PROJECT_ROOT="$(git rev-parse --show-toplevel)"

yank () {
  curl -s "http://api.etherscan.io/api?module=contract&action=getabi&address=$1&format=raw" -H "User-Agent: Chrome" > /tmp/$2
}

gen () {
  sleep 5
  echo "Download $2 abi (address: $1)..."
  yank $1 $2_abi.json
  echo "Genrating interface..."
  cat /tmp/$2_abi.json | npx abi-to-sol $2 > $PROJECT_ROOT/contracts/interfaces/thirdparty/$2.sol
  echo "Done."
  echo ""
}

gen "0xd51a44d3fae010294c616388b506acda1bfaae46" "ITricryptoPool" 
gen "0xdefd8fdd20e0f34115c7018ccfb655796f6b2168" "ILiquidityGaugeV3" 

echo "All done."