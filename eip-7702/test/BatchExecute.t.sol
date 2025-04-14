// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {BatchExecute} from "../src/BatchExecute.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract BatchExecuteTest is Test {
    // Alice's address and private key (EOA with no initial contract code).
    address payable ALICE_ADDRESS = payable(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
    uint256 constant ALICE_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    // Bob's address and private key (Bob will execute transactions on Alice's behalf).
    address constant BOB_ADDRESS = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    uint256 constant BOB_PK = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

    // The contract that Alice will delegate execution to.
    BatchExecute public implementation;

    // ERC-20 token contract for minting test tokens.
    MockERC20 public token;

    event CallExecuted(address indexed to, uint256 value, bytes data);
    event BatchExecuted(BatchExecute.Call[] calls);

    function setUp() public {
        // Deploy the delegation contract (Alice will delegate calls to this contract).
        implementation = new BatchExecute();

        // Deploy an ERC-20 token contract where Alice is the minter.
        token = new MockERC20();

        // Fund accounts
        vm.deal(ALICE_ADDRESS, 10 ether);
        token.mint(ALICE_ADDRESS, 1000e18);
    }

    function testDirectExecution() public {
        console2.log("Sending 1 ETH from Alice to Bob and transferring 100 tokens to Bob in a single transaction");
        BatchExecute.Call[] memory calls = new BatchExecute.Call[](2);

        // ETH transfer
        calls[0] = BatchExecute.Call({to: BOB_ADDRESS, value: 1 ether, data: ""});

        // Token transfer
        calls[1] = BatchExecute.Call({
            to: address(token),
            value: 0,
            data: abi.encodeCall(ERC20.transfer, (BOB_ADDRESS, 100e18))
        });

        vm.signAndAttachDelegation(address(implementation), ALICE_PK);

        vm.startPrank(ALICE_ADDRESS);
        BatchExecute(ALICE_ADDRESS).execute(calls);
        vm.stopPrank();

        assertEq(BOB_ADDRESS.balance, 1 ether);
        assertEq(token.balanceOf(BOB_ADDRESS), 100e18);
    }

}
