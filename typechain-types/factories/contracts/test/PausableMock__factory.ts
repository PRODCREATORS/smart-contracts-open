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
  "0x608060405234801561001057600080fd5b506002805460ff19169055610c808061002a6000396000f3fe608060405234801561001057600080fd5b50600436106100ba5760003560e01c806301ffc9a7146100bf578063248a9ca3146100e75780632f2ff15d1461010857806336568abe1461011d5780633f4ba83a146101305780635c975abb1461013857806382dc1ec4146101435780638456cb59146101565780639010d07c1461015e57806391d148541461017e578063a217fddf14610191578063ca15c87314610199578063d547741f146101ac578063e63ab1e9146101bf575b600080fd5b6100d26100cd3660046109bf565b6101d4565b60405190151581526020015b60405180910390f35b6100fa6100f53660046109e9565b6101ff565b6040519081526020016100de565b61011b610116366004610a1e565b610214565b005b61011b61012b366004610a1e565b610235565b61011b6102b8565b60025460ff166100d2565b61011b610151366004610a4a565b6102db565b61011b6102f3565b61017161016c366004610a65565b610313565b6040516100de9190610a87565b6100d261018c366004610a1e565b610332565b6100fa600081565b6100fa6101a73660046109e9565b61035b565b61011b6101ba366004610a1e565b610372565b6100fa600080516020610c2b83398151915281565b60006001600160e01b03198216635a05180f60e01b14806101f957506101f98261038e565b92915050565b60009081526020819052604090206001015490565b61021d826101ff565b610226816103c3565b61023083836103cd565b505050565b6001600160a01b03811633146102aa5760405162461bcd60e51b815260206004820152602f60248201527f416363657373436f6e74726f6c3a2063616e206f6e6c792072656e6f756e636560448201526e103937b632b9903337b91039b2b63360891b60648201526084015b60405180910390fd5b6102b482826103ef565b5050565b600080516020610c2b8339815191526102d0816103c3565b6102d8610411565b50565b6102d8600080516020610c2b833981519152826103cd565b600080516020610c2b83398151915261030b816103c3565b6102d861045d565b600082815260016020526040812061032b908361049a565b9392505050565b6000918252602082815260408084206001600160a01b0393909316845291905290205460ff1690565b60008181526001602052604081206101f9906104a6565b61037b826101ff565b610384816103c3565b61023083836103ef565b60006001600160e01b03198216637965db0b60e01b14806101f957506301ffc9a760e01b6001600160e01b03198316146101f9565b6102d881336104b0565b6103d78282610514565b60008281526001602052604090206102309082610598565b6103f982826105ad565b60008281526001602052604090206102309082610612565b610419610627565b6002805460ff191690557f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa335b6040516104539190610a87565b60405180910390a1565b610465610672565b6002805460ff191660011790557f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a2586104463390565b600061032b83836106b8565b60006101f9825490565b6104ba8282610332565b6102b4576104d2816001600160a01b031660146106e2565b6104dd8360206106e2565b6040516020016104ee929190610acb565b60408051601f198184030181529082905262461bcd60e51b82526102a191600401610b3a565b61051e8282610332565b6102b4576000828152602081815260408083206001600160a01b03851684529091529020805460ff191660011790556105543390565b6001600160a01b0316816001600160a01b0316837f2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d60405160405180910390a45050565b600061032b836001600160a01b03841661087d565b6105b78282610332565b156102b4576000828152602081815260408083206001600160a01b0385168085529252808320805460ff1916905551339285917ff6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b9190a45050565b600061032b836001600160a01b0384166108cc565b60025460ff166106705760405162461bcd60e51b815260206004820152601460248201527314185d5cd8589b194e881b9bdd081c185d5cd95960621b60448201526064016102a1565b565b60025460ff16156106705760405162461bcd60e51b815260206004820152601060248201526f14185d5cd8589b194e881c185d5cd95960821b60448201526064016102a1565b60008260000182815481106106cf576106cf610b6d565b9060005260206000200154905092915050565b606060006106f1836002610b99565b6106fc906002610bb8565b6001600160401b0381111561071357610713610bd0565b6040519080825280601f01601f19166020018201604052801561073d576020820181803683370190505b509050600360fc1b8160008151811061075857610758610b6d565b60200101906001600160f81b031916908160001a905350600f60fb1b8160018151811061078757610787610b6d565b60200101906001600160f81b031916908160001a90535060006107ab846002610b99565b6107b6906001610bb8565b90505b600181111561082e576f181899199a1a9b1b9c1cb0b131b232b360811b85600f16601081106107ea576107ea610b6d565b1a60f81b82828151811061080057610800610b6d565b60200101906001600160f81b031916908160001a90535060049490941c9361082781610be6565b90506107b9565b50831561032b5760405162461bcd60e51b815260206004820181905260248201527f537472696e67733a20686578206c656e67746820696e73756666696369656e7460448201526064016102a1565b60008181526001830160205260408120546108c4575081546001818101845560008481526020808220909301849055845484825282860190935260409020919091556101f9565b5060006101f9565b600081815260018301602052604081205480156109b55760006108f0600183610bfd565b855490915060009061090490600190610bfd565b905081811461096957600086600001828154811061092457610924610b6d565b906000526020600020015490508087600001848154811061094757610947610b6d565b6000918252602080832090910192909255918252600188019052604090208390555b855486908061097a5761097a610c14565b6001900381819060005260206000200160009055905585600101600086815260200190815260200160002060009055600193505050506101f9565b60009150506101f9565b6000602082840312156109d157600080fd5b81356001600160e01b03198116811461032b57600080fd5b6000602082840312156109fb57600080fd5b5035919050565b80356001600160a01b0381168114610a1957600080fd5b919050565b60008060408385031215610a3157600080fd5b82359150610a4160208401610a02565b90509250929050565b600060208284031215610a5c57600080fd5b61032b82610a02565b60008060408385031215610a7857600080fd5b50508035926020909101359150565b6001600160a01b0391909116815260200190565b60005b83811015610ab6578181015183820152602001610a9e565b83811115610ac5576000848401525b50505050565b76020b1b1b2b9b9a1b7b73a3937b61d1030b1b1b7bab73a1604d1b815260008351610afd816017850160208801610a9b565b7001034b99036b4b9b9b4b733903937b6329607d1b6017918401918201528351610b2e816028840160208801610a9b565b01602801949350505050565b6020815260008251806020840152610b59816040850160208701610a9b565b601f01601f19169190910160400192915050565b634e487b7160e01b600052603260045260246000fd5b634e487b7160e01b600052601160045260246000fd5b6000816000190483118215151615610bb357610bb3610b83565b500290565b60008219821115610bcb57610bcb610b83565b500190565b634e487b7160e01b600052604160045260246000fd5b600081610bf557610bf5610b83565b506000190190565b600082821015610c0f57610c0f610b83565b500390565b634e487b7160e01b600052603160045260246000fdfe65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862aa26469706673582212201d30f1dfcb69c22efe84434eb0a8a6ea75799fd9263435ce4a2459d3117fd74d64736f6c634300080f0033";

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
