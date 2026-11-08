// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployPlayToken} from "../script/DeployPlayToken.s.sol";
import {PlayToken} from "../src/PlayToken.sol";

contract DeployPlayTokenTest is Test {
    function test_ScriptMakesTheCallerOwner() public {
        DeployPlayToken script = new DeployPlayToken();
        PlayToken token = script.run();

        assertEq(token.owner(), address(this), "owner must be the caller, not the script");
        assertEq(token.balanceOf(address(this)), script.INITIAL_MINT());
    }
}
