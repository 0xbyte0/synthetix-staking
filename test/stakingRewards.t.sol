// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "src/stakingRewards.sol";
import "./mocks/ERC20.sol";

contract TestContract is Test {
    StakingRewards stakingContract;
    MockERC20 public stakingToken;
    MockERC20 public rewardsToken;

    function setUp() public {
        stakingToken = new MockERC20();
        rewardsToken = new MockERC20();
        stakingContract = new StakingRewards(address(stakingToken), address(rewardsToken));

        rewardsToken.mintTo(address(stakingContract), 1000000e18);
    }

    function _stake(uint256 amount) public {
        stakingToken.approve(address(stakingContract), amount);
        stakingContract.stake(amount);
    }

    function testStake() public {
        uint256 amount = 10e18;
        _stake(amount);
        assertEq(stakingContract.balanceOf(address(this)), amount, "ok");
    }

    function testWithdraw() public {
        uint256 amount = 10e18;
        _stake(amount);
        
        stakingContract.withdraw(amount);
        assertEq(stakingContract.balanceOf(address(this)), 0, "ok");
    }  

    function testGetReward() public {
        stakingContract.getReward();
    }

    function testEarned() public {
        uint256 amount = 1_000_000_000;
        uint256 _duration = block.timestamp + 3 days;
        _stake(amount);

        stakingContract.setRewardsDuration(_duration);
        assertEq(stakingContract.s_stakeDuration(), _duration);

        stakingContract.notifyRewardAmount(50_000_00);

        assertEq(stakingContract.s_endingAt(), stakingContract.s_updatedAt() + _duration, "ok");
        assertFalse(stakingContract.lastTimeRewardApplicable() == stakingContract.s_endingAt(), "ok");
    }
}
