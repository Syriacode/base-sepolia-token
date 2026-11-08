// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PlayToken} from "../src/PlayToken.sol";

contract PlayTokenTest is Test {
    PlayToken internal token;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant INITIAL = 1_000 ether;

    function setUp() public {
        vm.warp(1_700_000_000);
        token = new PlayToken(owner, INITIAL);
    }

    function test_Metadata() public view {
        assertEq(token.name(), "PlayToken");
        assertEq(token.symbol(), "PLAY");
        assertEq(token.decimals(), 18);
    }

    function test_ConstructorMintsToOwner() public view {
        assertEq(token.owner(), owner);
        assertEq(token.balanceOf(owner), INITIAL);
        assertEq(token.totalSupply(), INITIAL);
    }

    function test_RevertWhen_InitialMintAboveCap() public {
        uint256 max = token.MAX_SUPPLY();
        vm.expectRevert(abi.encodeWithSelector(PlayToken.CapExceeded.selector, max + 1, max));
        new PlayToken(owner, max + 1);
    }

    function test_ClaimMintsAndEmits() public {
        uint256 amount = token.CLAIM_AMOUNT();

        vm.expectEmit(true, false, false, true, address(token));
        emit PlayToken.Claimed(alice, amount);

        vm.prank(alice);
        token.claim();

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.nextClaimAt(alice), block.timestamp + token.CLAIM_COOLDOWN());
    }

    function test_RevertWhen_ClaimedTwiceTooSoon() public {
        vm.prank(alice);
        token.claim();

        uint256 next = token.nextClaimAt(alice);
        vm.warp(next - 1);

        vm.expectRevert(abi.encodeWithSelector(PlayToken.ClaimTooSoon.selector, next));
        vm.prank(alice);
        token.claim();
    }

    function test_ClaimAgainExactlyAfterCooldown() public {
        vm.prank(alice);
        token.claim();

        vm.warp(token.nextClaimAt(alice));

        vm.prank(alice);
        token.claim();

        assertEq(token.balanceOf(alice), 2 * token.CLAIM_AMOUNT());
    }

    function test_CooldownIsPerAddress() public {
        vm.prank(alice);
        token.claim();

        vm.prank(bob);
        token.claim();

        assertEq(token.balanceOf(bob), token.CLAIM_AMOUNT());
    }

    function test_OwnerMints() public {
        vm.prank(owner);
        token.mint(bob, 5 ether);

        assertEq(token.balanceOf(bob), 5 ether);
        assertEq(token.totalSupply(), INITIAL + 5 ether);
    }

    function test_RevertWhen_StrangerMints() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        token.mint(alice, 1);
    }

    function test_RevertWhen_MintAboveCap() public {
        uint256 available = token.MAX_SUPPLY() - token.totalSupply();

        vm.expectRevert(abi.encodeWithSelector(PlayToken.CapExceeded.selector, available + 1, available));
        vm.prank(owner);
        token.mint(bob, available + 1);
    }

    function test_RevertWhen_ClaimWouldExceedCap() public {
        uint256 available = token.MAX_SUPPLY() - token.totalSupply();
        vm.prank(owner);
        token.mint(bob, available - 1);

        vm.expectRevert(abi.encodeWithSelector(PlayToken.CapExceeded.selector, token.CLAIM_AMOUNT(), 1));
        vm.prank(alice);
        token.claim();

        assertEq(token.nextClaimAt(alice), 0);
    }

    function testFuzz_SupplyNeverExceedsCap(uint256 amount) public {
        amount = bound(amount, 0, 2 * token.MAX_SUPPLY());

        vm.prank(owner);
        try token.mint(bob, amount) {} catch {}

        assertLe(token.totalSupply(), token.MAX_SUPPLY());
    }
}
