// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract StakingRewards {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;

    address public owner;

    // Duration of rewards to be paid out (in seconds)
    uint public s_stakeDuration;
    // Timestamp of when the rewards finish
    uint public s_endingAt;
    // Minimum of last updated time and reward finish time
    uint public s_updatedAt;
    // Reward to be paid out per second
    uint public s_rewardRate;
    // Sum of (reward rate * dt * 1e18 / total supply)
    uint public s_rewardPerTokenStored;
    // User address => rewardPerTokenStored
    mapping(address => uint) public s_userRewardPerTokenPaid;
    // User address => rewards to be claimed
    mapping(address => uint) public s_rewards;

    // Total staked
    uint public totalSupply;
    // User address => staked amount
    mapping(address => uint) public balanceOf;

    constructor(address _stakingToken, address _rewardToken) {
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardToken);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not authorized");
        _;
    }

    modifier updateReward(address _account) {
        s_rewardPerTokenStored = rewardPerToken();
        s_updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            s_rewards[_account] = earned(_account);
            s_userRewardPerTokenPaid[_account] = s_rewardPerTokenStored;
        }

        _;
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        return _min(s_endingAt, block.timestamp);
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return s_rewardPerTokenStored;
        }

        return
            s_rewardPerTokenStored +
            (s_rewardRate * (lastTimeRewardApplicable() - s_updatedAt) * 1e18) /
            totalSupply;
    }

    function stake(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
    }

    function withdraw(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    function earned(address _account) public view returns (uint) {
        return
            ((balanceOf[_account] *
                (rewardPerToken() - s_userRewardPerTokenPaid[_account])) / 1e18) +
            s_rewards[_account];
    }

    function getReward() external updateReward(msg.sender) {
        uint reward = s_rewards[msg.sender];
        if (reward > 0) {
            s_rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }

    function setRewardsDuration(uint _duration) external onlyOwner {
        require(s_endingAt < block.timestamp, "reward duration not finished");
        s_stakeDuration = _duration;
    }

    function notifyRewardAmount(uint _amount)
        external
        onlyOwner
    {
        if (block.timestamp >= s_endingAt) {
            s_rewardRate = _amount / s_stakeDuration;
        } else {
            uint remainingRewards = (s_endingAt - block.timestamp) * s_rewardRate;
            s_rewardRate = (_amount + remainingRewards) / s_stakeDuration;
        }

        require(s_rewardRate > 0, "reward rate = 0");
        require(
            s_rewardRate * s_stakeDuration <= rewardsToken.balanceOf(address(this)),
            "reward amount > balance"
        );

        s_endingAt = block.timestamp + s_stakeDuration;
        s_updatedAt = block.timestamp;
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }
}