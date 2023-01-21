const { readFileSync, readdirSync, writeFileSync } = require("fs");
const _ = require('lodash');
const path = require("path");
const deploys = path.join(__dirname, 'deploy', 'addresses');
const files = readdirSync(deploys).filter(e => /^t[a-z]+_addresses/g.test(e));

const keys = files.map(e => e.replace('_addresses.json', ''));
const items = files.map(e => path.join(deploys, e)).map(e => readFileSync(e)).map(e => JSON.parse(e));

const obj = _.zipObject(keys, items);
const tpl = process.argv[2];

const txt = readFileSync(tpl).toString('utf-8');
const out = txt.replaceAll(/\{\{\s*[a-zA-Z.]+\s*\}\}/g, x => {
  const path = x.replace('{{', '').replace('}}', '').trim()
  const val = _.get(obj, path);
  console.log(path, '=', val);
  return val;
});

writeFileSync(tpl.replace('.tpl',''), out);