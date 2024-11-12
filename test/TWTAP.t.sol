// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/TWTAP.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18); // Mint initial supply to deployer
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract TWTAPTest is Test {
    TWTAP public twtap;
    MockERC20 public tapToken;
    address public owner;
    address public user1;
    address public user2;
    MockERC20 public rewardToken1;
    MockERC20 public rewardToken2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        tapToken = new MockERC20("TAP Token", "TAP");
        twtap = new TWTAP(payable(address(tapToken)), owner);

        rewardToken1 = new MockERC20("Reward Token 1", "RWD1");
        rewardToken2 = new MockERC20("Reward Token 2", "RWD2");

        // Add reward tokens to TWTAP contract
        vm.prank(owner);
        twtap.addRewardToken(IERC20(address(rewardToken1)));
        vm.prank(owner);
        twtap.addRewardToken(IERC20(address(rewardToken2)));

        // Mint some TAP tokens to users for testing
        tapToken.mint(user1, 1000 * 10**18);
        tapToken.mint(user2, 1000 * 10**18);
    }

    function testParticipate() public {
        uint256 amount = 100 * 10**18;
        uint256 duration = 7 days; // 1 EPOCH
        uint256 minReward = 0;

        vm.startPrank(user1);
        tapToken.approve(address(twtap), amount);
        uint256 tokenId = twtap.participate(user1, amount, duration, minReward);
        vm.stopPrank();

        assertEq(twtap.ownerOf(tokenId), user1);
            assertEq(tapToken.balanceOf(address(twtap)), amount);
        (Participation memory p, uint256[] memory c) = twtap.getPosition(tokenId); // Get both return values

        assertEq(p.tapAmount, amount);
        assertEq(p.expiry, block.timestamp + duration);
    }

    function testFailParticipateWithInsufficientApproval() public {
        uint256 amount = 100 * 10**18;
        uint256 duration = 7 days;
        uint256 minReward = 0;

        vm.startPrank(user1);
        tapToken.approve(address(twtap), amount - 1); // Insufficient approval
        vm.expectRevert(); // Expect revert due to insufficient approval
        twtap.participate(user1, amount, duration, minReward);
        vm.stopPrank();
    }

    function testClaimable() public {
        uint256 amount = 100 * 10**18;
        uint256 duration = 7 days;
        uint256 minReward = 0;

        vm.startPrank(user1);
        tapToken.approve(address(twtap), amount);
        uint256 tokenId = twtap.participate(user1, amount, duration, minReward);
        vm.stopPrank();

        // Advance time and distribute some rewards
        vm.warp(block.timestamp + duration); // Move time forward by the duration
        vm.prank(owner);
        
       // Distribute rewards after advancing time
       uint256 rewardAmount = 1000 * 10**18; 
       rewardToken1.mint(owner, rewardAmount); 
       rewardToken1.approve(address(twtap), rewardAmount); 
       twtap.distributeReward(0, rewardAmount); 

       // Check claimable amounts
       uint256[] memory claimableAmounts = twtap.claimable(tokenId); 
       assertGt(claimableAmounts[0], 0); // Assert that there's some claimable reward
   }

   function testExitPosition() public {
       uint256 amount = 100 * 10**18;
       uint256 duration = 7 days;
       uint256 minReward = 0;

       vm.startPrank(user1);
       tapToken.approve(address(twtap), amount);
       uint256 tokenId = twtap.participate(user1, amount, duration, minReward);
       vm.stopPrank();

       // Advance time past lock duration
       vm.warp(block.timestamp + duration + 1 days);

       vm.prank(user1);
       twtap.exitPosition(tokenId);

       assertEq(tapToken.balanceOf(user1), amount); // Check if TAP tokens were returned
        (Participation memory p, uint256[] memory c) = twtap.getPosition(tokenId); // Get both return values

        assertEq(p.tapAmount, 0);
        assertTrue(p.tapReleased);
   }

   function testAdvanceWeek() public {
       uint256 initialWeek = twtap.lastProcessedWeek();

       vm.warp(block.timestamp + 7 days); // Move time forward by one week

       vm.prank(owner);
       twtap.advanceWeek(1);

       assertEq(twtap.lastProcessedWeek(), initialWeek + 1); // Ensure week is advanced correctly
   }

//    function testAddRewardToken() public {
//        MockERC20 newRewardToken = new MockERC20("New Reward", "NRW");

//        uint256 initialCount = twtap.getRewardTokens().length;

//        vm.prank(owner);
//        twtap.addRewardToken(address(newRewardToken));
//        IERC20[] memory rewardTokens = twtap.getRewardTokens();
//        assertEq(rewardTokens.length, initialCount + 1); // Ensure new token was added
//    }

//    function testFailAddRewardTokenNonOwner() public {
//        MockERC20 newRewardToken = new MockERC20("New Reward", "NRW");

//        vm.prank(user1); // Non-owner tries to add a reward token
//        vm.expectRevert(); // Expect revert due to non-owner access
//        twtap.addRewardToken(address(newRewardToken));
//    }
}