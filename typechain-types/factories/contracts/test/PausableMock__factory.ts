/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../../../common";
import type {
  PausableMock,
  PausableMockInterface,
} from "../../../contracts/test/PausableMock";

const _abi = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "Paused",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
      {
        indexed: true,
        internalType: "bytes32",
        name: "previousAdminRole",
        type: "bytes32",
      },
      {
        indexed: true,
        internalType: "bytes32",
        name: "newAdminRole",
        type: "bytes32",
      },
    ],
    name: "RoleAdminChanged",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
      {
        indexed: true,
        internalType: "address",
        name: "account",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "sender",
        type: "address",
      },
    ],
    name: "RoleGranted",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
      {
        indexed: true,
        internalType: "address",
        name: "account",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "sender",
        type: "address",
      },
    ],
    name: "RoleRevoked",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "Unpaused",
    type: "event",
  },
  {
    inputs: [],
    name: "DEFAULT_ADMIN_ROLE",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "PAUSER_ROLE",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_account",
        type: "address",
      },
    ],
    name: "addPauser",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
    ],
    name: "getRoleAdmin",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
      {
        internalType: "uint256",
        name: "index",
        type: "uint256",
      },
    ],
    name: "getRoleMember",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
    ],
    name: "getRoleMemberCount",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "grantRole",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "hasRole",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "pause",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "paused",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "renounceRole",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "revokeRole",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes4",
        name: "interfaceId",
        type: "bytes4",
      },
    ],
    name: "supportsInterface",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "unpause",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const _bytecode =
  "0x608060405234801561001057600080fd5b5060008060006101000a81548160ff0219169083151502179055506117ff8061003a6000396000f3fe608060405234801561001057600080fd5b50600436106100ea5760003560e01c80638456cb591161008c578063a217fddf11610066578063a217fddf14610235578063ca15c87314610253578063d547741f14610283578063e63ab1e91461029f576100ea565b80638456cb59146101cb5780639010d07c146101d557806391d1485414610205576100ea565b806336568abe116100c857806336568abe1461016b5780633f4ba83a146101875780635c975abb1461019157806382dc1ec4146101af576100ea565b806301ffc9a7146100ef578063248a9ca31461011f5780632f2ff15d1461014f575b600080fd5b61010960048036038101906101049190610fdb565b6102bd565b6040516101169190611023565b60405180910390f35b61013960048036038101906101349190611074565b610337565b60405161014691906110b0565b60405180910390f35b61016960048036038101906101649190611129565b610357565b005b61018560048036038101906101809190611129565b610378565b005b61018f6103fb565b005b610199610430565b6040516101a69190611023565b60405180910390f35b6101c960048036038101906101c49190611169565b610446565b005b6101d3610473565b005b6101ef60048036038101906101ea91906111cc565b6104a8565b6040516101fc919061121b565b60405180910390f35b61021f600480360381019061021a9190611129565b6104d7565b60405161022c9190611023565b60405180910390f35b61023d610542565b60405161024a91906110b0565b60405180910390f35b61026d60048036038101906102689190611074565b610549565b60405161027a9190611245565b60405180910390f35b61029d60048036038101906102989190611129565b61056d565b005b6102a761058e565b6040516102b491906110b0565b60405180910390f35b60007f5a05180f000000000000000000000000000000000000000000000000000000007bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916827bffffffffffffffffffffffffffffffffffffffffffffffffffffffff19161480610330575061032f826105b2565b5b9050919050565b600060016000838152602001908152602001600020600101549050919050565b61036082610337565b6103698161062c565b6103738383610640565b505050565b610380610674565b73ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff16146103ed576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016103e4906112e3565b60405180910390fd5b6103f7828261067c565b5050565b7f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a6104258161062c565b61042d6106b0565b50565b60008060009054906101000a900460ff16905090565b6104707f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a82610640565b50565b7f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a61049d8161062c565b6104a5610712565b50565b60006104cf826002600086815260200190815260200160002061077490919063ffffffff16565b905092915050565b60006001600084815260200190815260200160002060000160008373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060009054906101000a900460ff16905092915050565b6000801b81565b60006105666002600084815260200190815260200160002061078e565b9050919050565b61057682610337565b61057f8161062c565b610589838361067c565b505050565b7f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a81565b60007f7965db0b000000000000000000000000000000000000000000000000000000007bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916827bffffffffffffffffffffffffffffffffffffffffffffffffffffffff191614806106255750610624826107a3565b5b9050919050565b61063d81610638610674565b61080d565b50565b61064a82826108aa565b61066f816002600085815260200190815260200160002061098a90919063ffffffff16565b505050565b600033905090565b61068682826109ba565b6106ab8160026000858152602001908152602001600020610a9c90919063ffffffff16565b505050565b6106b8610acc565b60008060006101000a81548160ff0219169083151502179055507f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa6106fb610674565b604051610708919061121b565b60405180910390a1565b61071a610b15565b60016000806101000a81548160ff0219169083151502179055507f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a25861075d610674565b60405161076a919061121b565b60405180910390a1565b60006107838360000183610b5f565b60001c905092915050565b600061079c82600001610b8a565b9050919050565b60007f01ffc9a7000000000000000000000000000000000000000000000000000000007bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916827bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916149050919050565b61081782826104d7565b6108a65761083c8173ffffffffffffffffffffffffffffffffffffffff166014610b9b565b61084a8360001c6020610b9b565b60405160200161085b929190611415565b6040516020818303038152906040526040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161089d9190611499565b60405180910390fd5b5050565b6108b482826104d7565b61098657600180600084815260200190815260200160002060000160008373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060006101000a81548160ff02191690831515021790555061092b610674565b73ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff16837f2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d60405160405180910390a45b5050565b60006109b2836000018373ffffffffffffffffffffffffffffffffffffffff1660001b610dd7565b905092915050565b6109c482826104d7565b15610a985760006001600084815260200190815260200160002060000160008373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060006101000a81548160ff021916908315150217905550610a3d610674565b73ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff16837ff6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b60405160405180910390a45b5050565b6000610ac4836000018373ffffffffffffffffffffffffffffffffffffffff1660001b610e47565b905092915050565b610ad4610430565b610b13576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401610b0a90611507565b60405180910390fd5b565b610b1d610430565b15610b5d576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401610b5490611573565b60405180910390fd5b565b6000826000018281548110610b7757610b76611593565b5b9060005260206000200154905092915050565b600081600001805490509050919050565b606060006002836002610bae91906115f1565b610bb8919061164b565b67ffffffffffffffff811115610bd157610bd06116a1565b5b6040519080825280601f01601f191660200182016040528015610c035781602001600182028036833780820191505090505b5090507f300000000000000000000000000000000000000000000000000000000000000081600081518110610c3b57610c3a611593565b5b60200101907effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916908160001a9053507f780000000000000000000000000000000000000000000000000000000000000081600181518110610c9f57610c9e611593565b5b60200101907effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916908160001a90535060006001846002610cdf91906115f1565b610ce9919061164b565b90505b6001811115610d89577f3031323334353637383961626364656600000000000000000000000000000000600f861660108110610d2b57610d2a611593565b5b1a60f81b828281518110610d4257610d41611593565b5b60200101907effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916908160001a905350600485901c945080610d82906116d0565b9050610cec565b5060008414610dcd576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401610dc490611746565b60405180910390fd5b8091505092915050565b6000610de38383610f5b565b610e3c578260000182908060018154018082558091505060019003906000526020600020016000909190919091505582600001805490508360010160008481526020019081526020016000208190555060019050610e41565b600090505b92915050565b60008083600101600084815260200190815260200160002054905060008114610f4f576000600182610e799190611766565b9050600060018660000180549050610e919190611766565b9050818114610f00576000866000018281548110610eb257610eb1611593565b5b9060005260206000200154905080876000018481548110610ed657610ed5611593565b5b90600052602060002001819055508387600101600083815260200190815260200160002081905550505b85600001805480610f1457610f1361179a565b5b600190038181906000526020600020016000905590558560010160008681526020019081526020016000206000905560019350505050610f55565b60009150505b92915050565b600080836001016000848152602001908152602001600020541415905092915050565b600080fd5b60007fffffffff0000000000000000000000000000000000000000000000000000000082169050919050565b610fb881610f83565b8114610fc357600080fd5b50565b600081359050610fd581610faf565b92915050565b600060208284031215610ff157610ff0610f7e565b5b6000610fff84828501610fc6565b91505092915050565b60008115159050919050565b61101d81611008565b82525050565b60006020820190506110386000830184611014565b92915050565b6000819050919050565b6110518161103e565b811461105c57600080fd5b50565b60008135905061106e81611048565b92915050565b60006020828403121561108a57611089610f7e565b5b60006110988482850161105f565b91505092915050565b6110aa8161103e565b82525050565b60006020820190506110c560008301846110a1565b92915050565b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b60006110f6826110cb565b9050919050565b611106816110eb565b811461111157600080fd5b50565b600081359050611123816110fd565b92915050565b600080604083850312156111405761113f610f7e565b5b600061114e8582860161105f565b925050602061115f85828601611114565b9150509250929050565b60006020828403121561117f5761117e610f7e565b5b600061118d84828501611114565b91505092915050565b6000819050919050565b6111a981611196565b81146111b457600080fd5b50565b6000813590506111c6816111a0565b92915050565b600080604083850312156111e3576111e2610f7e565b5b60006111f18582860161105f565b9250506020611202858286016111b7565b9150509250929050565b611215816110eb565b82525050565b6000602082019050611230600083018461120c565b92915050565b61123f81611196565b82525050565b600060208201905061125a6000830184611236565b92915050565b600082825260208201905092915050565b7f416363657373436f6e74726f6c3a2063616e206f6e6c792072656e6f756e636560008201527f20726f6c657320666f722073656c660000000000000000000000000000000000602082015250565b60006112cd602f83611260565b91506112d882611271565b604082019050919050565b600060208201905081810360008301526112fc816112c0565b9050919050565b600081905092915050565b7f416363657373436f6e74726f6c3a206163636f756e7420000000000000000000600082015250565b6000611344601783611303565b915061134f8261130e565b601782019050919050565b600081519050919050565b60005b83811015611383578082015181840152602081019050611368565b83811115611392576000848401525b50505050565b60006113a38261135a565b6113ad8185611303565b93506113bd818560208601611365565b80840191505092915050565b7f206973206d697373696e6720726f6c6520000000000000000000000000000000600082015250565b60006113ff601183611303565b915061140a826113c9565b601182019050919050565b600061142082611337565b915061142c8285611398565b9150611437826113f2565b91506114438284611398565b91508190509392505050565b6000601f19601f8301169050919050565b600061146b8261135a565b6114758185611260565b9350611485818560208601611365565b61148e8161144f565b840191505092915050565b600060208201905081810360008301526114b38184611460565b905092915050565b7f5061757361626c653a206e6f7420706175736564000000000000000000000000600082015250565b60006114f1601483611260565b91506114fc826114bb565b602082019050919050565b60006020820190508181036000830152611520816114e4565b9050919050565b7f5061757361626c653a2070617573656400000000000000000000000000000000600082015250565b600061155d601083611260565b915061156882611527565b602082019050919050565b6000602082019050818103600083015261158c81611550565b9050919050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052603260045260246000fd5b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b60006115fc82611196565b915061160783611196565b9250817fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff04831182151516156116405761163f6115c2565b5b828202905092915050565b600061165682611196565b915061166183611196565b9250827fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff03821115611696576116956115c2565b5b828201905092915050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b60006116db82611196565b915060008214156116ef576116ee6115c2565b5b600182039050919050565b7f537472696e67733a20686578206c656e67746820696e73756666696369656e74600082015250565b6000611730602083611260565b915061173b826116fa565b602082019050919050565b6000602082019050818103600083015261175f81611723565b9050919050565b600061177182611196565b915061177c83611196565b92508282101561178f5761178e6115c2565b5b828203905092915050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052603160045260246000fdfea2646970667358221220bb75be8c9bfc0f20cb2c488b37729519c4b0c344c0462551ad13b29b8d6c738a64736f6c634300080a0033";

type PausableMockConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: PausableMockConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class PausableMock__factory extends ContractFactory {
  constructor(...args: PausableMockConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<PausableMock> {
    return super.deploy(overrides || {}) as Promise<PausableMock>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): PausableMock {
    return super.attach(address) as PausableMock;
  }
  override connect(signer: Signer): PausableMock__factory {
    return super.connect(signer) as PausableMock__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): PausableMockInterface {
    return new utils.Interface(_abi) as PausableMockInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): PausableMock {
    return new Contract(address, _abi, signerOrProvider) as PausableMock;
  }
}
