// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import "../src/TWTAP.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Minimal ERC20 implementation for testing
contract TestERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract TWTAPTest is Test {
    TWTAP public twTap;
    TestERC20 public tap;
    TestERC20 public rewardToken1;
    TestERC20 public rewardToken2;
    address public owner;
    address public addr1;
    address public addr2;

    // Setup test environment
    function setUp() public {
        owner = address(this);
        addr1 = address(0x1);
        addr2 = address(0x2);

        // Deploy TAP token contract
        tap = new TestERC20("TAP Token", "TAP");
        
        // Deploy reward token contracts
        rewardToken1 = new TestERC20("Reward Token 1", "RWD1");
        rewardToken2 = new TestERC20("Reward Token 2", "RWD2");

        // Deploy TWTAP contract
        twTap = new TWTAP(payable(address(tap)), owner);

        // Add reward tokens
        twTap.addRewardToken(IERC20(address(rewardToken1)));
        twTap.addRewardToken(IERC20(address(rewardToken2)));

        // Mint initial supply
        tap.mint(owner, 1_000_000 ether);
        rewardToken1.mint(owner, 1_000_000 ether);
        rewardToken2.mint(owner, 1_000_000 ether);
    }

    // Test contract deployment and initialization
    function testDeployment() public {
        assertEq(twTap.owner(), owner, "Owner should be set correctly");
        (,,, uint256 cumulative) = twTap.twAML();
        uint256 expectedCumulative = 4 * 7 * 86400; // 4 weeks in seconds
        assertEq(cumulative, expectedCumulative, "Initial cumulative should be set correctly");
    }

    // Test normal participation
    function testParticipate() public {
        uint256 amount = 1000 ether;
        uint256 duration = 7 days;
        uint256 minReward = 50000;

        // Transfer TAP to addr1
        vm.startPrank(owner);
        tap.transfer(addr1, amount);
        vm.stopPrank();

        // addr1 approves TWTAP contract to transfer TAP
        vm.startPrank(addr1);
        tap.approve(address(twTap), amount);

        // Participate
        vm.expectEmit(true, true, true, true);
        emit TWTAP.Participate(addr1, 1, amount, 1_000_000, duration);
        twTap.participate(addr1, amount, duration, minReward);
        vm.stopPrank();

        // Check if ERC721 token is minted
        assertEq(twTap.balanceOf(addr1), 1, "ERC721 token should be minted to addr1");

        // Check participation info
        (
            uint256 averageMagnitude,
            bool hasVotingPower,
            bool divergenceForce,
            bool tapReleased,
            uint56 lockedAt,
            uint56 expiry,
            uint88 tapAmount,
            uint24 multiplier,
            uint40 lastInactive,
            uint40 lastActive
        ) = twTap.participants(1);
        assertEq(tapAmount, amount, "tapAmount should be correct");
        assertEq(expiry, twTap.creation() + duration, "expiry should be set correctly");
    }

    // Test lock duration less than a week
    function testParticipate_Revert_LockNotAWeek() public {
        uint256 amount = 1000 ether;
        uint256 duration = 6 days; // Less than a week
        uint256 minReward = 50000;

        vm.startPrank(owner);
        tap.transfer(addr1, amount);
        vm.stopPrank();

        vm.startPrank(addr1);
        tap.approve(address(twTap), amount);

        vm.expectRevert("LockNotAWeek");
        twTap.participate(addr1, amount, duration, minReward);
        vm.stopPrank();
    }

    // Test lock duration not multiple of a week
    function testParticipate_Revert_DurationNotMultiple() public {
        uint256 amount = 1000 ether;
        uint256 duration = 10 days; // Not a multiple of a week
        uint256 minReward = 50000;

        vm.startPrank(owner);
        tap.transfer(addr1, amount);
        vm.stopPrank();

        vm.startPrank(addr1);
        tap.approve(address(twTap), amount);

        vm.expectRevert("DurationNotMultiple");
        twTap.participate(addr1, amount, duration, minReward);
        vm.stopPrank();
    }

    // Test lock duration exceeding maximum limit
    function testParticipate_Revert_LockTooLong() public {
        uint256 amount = 1000 ether;
        uint256 duration = 6 * 365 days; // 6 years, exceeds 5 years
        uint256 minReward = 50000;

        vm.startPrank(owner);
        tap.transfer(addr1, amount);
        vm.stopPrank();

        vm.startPrank(addr1);
        tap.approve(address(twTap), amount);

        vm.expectRevert("LockTooLong");
        twTap.participate(addr1, amount, duration, minReward);
        vm.stopPrank();
    }

    // Test claiming rewards
    function testClaimRewards() public {
        uint256 amount = 1000 ether;
        uint256 duration = 7 days;
        uint256 minReward = 50000;

        vm.startPrank(owner);
        tap.transfer(addr1, amount);
        vm.stopPrank();

        vm.startPrank(addr1);
        tap.approve(address(twTap), amount);
        twTap.participate(addr1, amount, duration, minReward);
        vm.stopPrank();

        vm.warp(block.timestamp + duration + 1);
        twTap.advanceWeek(1);

        uint256 rewardAmount1 = 500 ether;
        uint256 rewardAmount2 = 300 ether;

        vm.startPrank(owner);
        rewardToken1.transfer(address(twTap), rewardAmount1);
        twTap.distributeReward(1, rewardAmount1);
        rewardToken2.transfer(address(twTap), rewardAmount2);
        twTap.distributeReward(2, rewardAmount2);
        vm.stopPrank();

        vm.startPrank(addr1);
        twTap.claimRewards(1);
        vm.stopPrank();

        assertEq(rewardToken1.balanceOf(addr1), rewardAmount1, "RewardToken1 balance should be correct");
        assertEq(rewardToken2.balanceOf(addr1), rewardAmount2, "RewardToken2 balance should be correct");
    }

    // Test exiting position
    function testExitPosition() public {
        uint256 amount = 1000 ether;
        uint256 duration = 7 days;
        uint256 minReward = 50000;

        vm.startPrank(owner);
        tap.transfer(addr1, amount);
        vm.stopPrank();

        vm.startPrank(addr1);
        tap.approve(address(twTap), amount);
        twTap.participate(addr1, amount, duration, minReward);
        vm.stopPrank();

        vm.warp(block.timestamp + duration + 1);
        twTap.advanceWeek(1);

        vm.startPrank(addr1);
        twTap.exitPosition(1);
        vm.stopPrank();

        assertEq(tap.balanceOf(addr1), amount, "TAP balance should be returned to addr1");

        (
            ,,,
            bool tapReleased,
            ,,,
            uint88 tapAmount,
            ,
        ) = twTap.participants(1);
        assertTrue(tapReleased, "tapReleased should be true");
        assertEq(tapAmount, 0, "tapAmount should be 0 after exit");
    }

    // Test early exit in rescue mode
    function testExitPosition_RescueMode() public {
        uint256 amount = 1000 ether;
        uint256 duration = 7 days;
        uint256 minReward = 50000;

        vm.startPrank(owner);
        tap.transfer(addr1, amount);
        vm.stopPrank();

        vm.startPrank(addr1);
        tap.approve(address(twTap), amount);
        twTap.participate(addr1, amount, duration, minReward);
        vm.stopPrank();

        vm.startPrank(owner);
        twTap.setRescueMode(true);
        vm.stopPrank();

        vm.startPrank(addr1);
        twTap.exitPosition(1);
        vm.stopPrank();

        assertEq(tap.balanceOf(addr1), amount, "TAP balance should be returned to addr1");

        (
            ,,,
            bool tapReleased,
            ,,,
            uint88 tapAmount,
            ,
        ) = twTap.participants(1);
        assertTrue(tapReleased, "tapReleased should be true");
        assertEq(tapAmount, 0, "tapAmount should be 0 after exit");
    }

    // Test emergency sweep
    function testEmergencySweep() public {
        uint256 amount = 1000 ether;
        uint256 duration = 7 days;
        uint256 minReward = 50000;

        vm.startPrank(owner);
        tap.transfer(addr1, amount);
        vm.stopPrank();

        vm.startPrank(addr1);
        tap.approve(address(twTap), amount);
        twTap.participate(addr1, amount, duration, minReward);
        vm.stopPrank();

        vm.startPrank(owner);
        twTap.activateEmergencySweep();
        vm.stopPrank();

        vm.warp(block.timestamp + 2 days + 1);

        vm.startPrank(owner);
        twTap.emergencySweep();
        vm.stopPrank();

        assertEq(tap.balanceOf(owner), 1_000_000 ether, "TAP should be swept to owner");
        assertEq(rewardToken1.balanceOf(owner), 1_000_000 ether, "RewardToken1 should be swept to owner");
        assertEq(rewardToken2.balanceOf(owner), 1_000_000 ether, "RewardToken2 should be swept to owner");
    }
}