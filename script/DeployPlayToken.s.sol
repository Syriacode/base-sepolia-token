// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {PlayToken} from "../src/PlayToken.sol";

contract DeployPlayToken is Script {
    uint256 public constant INITIAL_MINT = 10_000 ether;

    function run() external returns (PlayToken token) {
        vm.startBroadcast();
        token = new PlayToken(msg.sender, INITIAL_MINT);
        vm.stopBroadcast();

        console.log("PlayToken deployed at:", address(token));
        console.log("Owner:", token.owner());
    }
}
