// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";
import "./Interfaces/ILPTokenWrapper.sol";
import "./Interfaces/IUnipool.sol";


// Adapted from: https://github.com/liquity/dev/blob/bf1d758a6638f900cc055a89156bdaa5188cc313/packages/contracts/contracts/LPRewards/Unipool.sol
// Which in turn is adapted from: https://github.com/Synthetixio/Unipool/blob/master/contracts/Unipool.sol
// Some more useful references:
// Synthetix proposal: https://sips.synthetix.io/sips/sip-31
// Original audits:
// https://github.com/sigp/public-audits/blob/master/synthetix/unipool/review.pdf
// https://www.coinspect.com/doc/Liquity%20-%20Smart%20Contract%20Audit%202021.pdf
// https://github.com/trailofbits/publications/blob/master/reviews/LiquityProtocolandStabilityPoolFinalReport.pdf
// Incremental changes (commit by commit) from the original to this version: TODO

// LPTokenWrapper contains the basic staking functionality
contract LPTokenWrapper is ILPTokenWrapper {
    using SafeERC20 for IERC20;

    IERC20 public uniToken;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public virtual override {
        _totalSupply = _totalSupply + amount;
        _balances[msg.sender] = _balances[msg.sender] + amount;
        uniToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public virtual override {
        _totalSupply = _totalSupply - amount;
        _balances[msg.sender] = _balances[msg.sender] - amount;
        uniToken.safeTransfer(msg.sender, amount);
    }
}

/*
 * On deployment a new Uniswap pool will be created for the pair LUSD/sLUSD and its token will be set here.

 * Essentially the way it works is:

 * - Liquidity providers add funds to the Uniswap pool, and get UNIv2 LP tokens in exchange
 * - Liquidity providers stake those UNIv2 LP tokens into Unipool rewards contract
 * - Liquidity providers accrue rewards, proportional to the amount of staked tokens and staking time
 * - Liquidity providers can claim their rewards when they want
 * - Liquidity providers can unstake UNIv2 LP tokens to exit the program (i.e., stop earning rewards) when they want

 * Funds for rewards will be added on every chicken in event.

 * If at some point the total amount of staked tokens is zero, the clock will be “stopped”,
 * so the period will be extended by the time during which the staking pool is empty,
 * in order to avoid getting LUSD tokens locked.
 */
contract Unipool is LPTokenWrapper, IUnipool {
    using SafeERC20 for IERC20;

    string constant public NAME = "Unipool";
    uint256 constant public INITIAL_DURATION = 3628800; // 6 weeks

    uint256 public duration;
    IERC20 public rewardToken;

    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event RewardTokenAddressChanged(address _rewardTokenAddress);
    event UniTokenAddressChanged(address _uniTokenAddress);
    event RewardAdded(uint256 reward, uint256 periodFinish);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    // initialization function
    constructor(
        address _rewardTokenAddress,
        address _uniTokenAddress
    )
    {
        Address.isContract(_rewardTokenAddress);
        Address.isContract(_uniTokenAddress);

        uniToken = IERC20(_uniTokenAddress);
        rewardToken = IERC20(_rewardTokenAddress);

        emit RewardTokenAddressChanged(_rewardTokenAddress);
        emit UniTokenAddressChanged(_uniTokenAddress);
    }

    // Returns current timestamp if the rewards program has not finished yet, end time otherwise
    function lastTimeRewardApplicable() public view override returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    // Returns the amount of rewards that correspond to each staked token
    function rewardPerToken() public view override returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored + (
                (lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18 / totalSupply()
            );
    }

    // Returns the amount that an account can claim
    function earned(address account) public view override returns (uint256) {
        return rewards[account] +
            balanceOf(account) * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18;
    }

    // stake visibility is public as overriding LPTokenWrapper's stake() function
    function stake(uint256 amount) public override {
        require(amount > 0, "Cannot stake 0");

        _updatePeriodFinish();
        _updateAccountReward(msg.sender);

        super.stake(amount);

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public override {
        require(amount > 0, "Cannot withdraw 0");

        _updateAccountReward(msg.sender);

        super.withdraw(amount);

        emit Withdrawn(msg.sender, amount);
    }

    // Shortcut to be able to unstake tokens and claim rewards in one transaction
    function withdrawAndClaim() external override {
        withdraw(balanceOf(msg.sender));
        claimReward();
    }

    function claimReward() public override {
        _updatePeriodFinish();
        _updateAccountReward(msg.sender);

        uint256 reward = earned(msg.sender);

        require(reward > 0, "Nothing to claim");

        rewards[msg.sender] = 0;
        rewardToken.transfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

    // Used each time new rewards are added
    // It pulls reward tokens from sender, so it must have an approval
    function pullRewardAmount(uint256 _reward) external {
        assert(_reward > 0);

        _updatePeriodFinish();
        rewardPerTokenStored = rewardPerToken();

        uint256 newReward;
        uint256 newDuration;
        uint256 periodFinishCached = periodFinish;
        if (periodFinish == 0 || periodFinishCached <= block.timestamp) { // it hasn’t started yet, or it has finished
            newDuration = INITIAL_DURATION;
            newReward = _reward;
        } else { // the program is on-going, we try to keep the rewardRate constant up to INITIAL_DURATION
            assert(rewardRate > 0);
            // we solve the equation new reward rate = previous reward rate, i.e.,
            // (reward + _reward) / (currentDuration + durationExtension) = rewardRate
            uint256 currentDuration = periodFinishCached - block.timestamp;
            uint256 durationExtension = _reward / rewardRate;
            // we cap it at INITIAL_DURATION
            newDuration = Math.min(currentDuration + durationExtension, INITIAL_DURATION);
            newReward = rewardRate * currentDuration + _reward;
        }

        rewardRate = newReward / newDuration;

        lastUpdateTime = block.timestamp;
        uint256 newPeriodFinish = block.timestamp + newDuration;
        periodFinish = newPeriodFinish;

        // pull reward tokens from sender
        rewardToken.safeTransferFrom(msg.sender, address(this), _reward);

        emit RewardAdded(_reward, newPeriodFinish);
    }

    // Adjusts end time for the program after periods of zero total supply
    function _updatePeriodFinish() internal {
        if (totalSupply() == 0) {
            // TODO:
            //assert(periodFinish > 0);
            /*
             * If the finish period has been reached (but there are remaining rewards due to zero stake),
             * to get the new finish date we must add to the current timestamp the difference between
             * the original finish time and the last update, i.e.:
             *
             * periodFinish = block.timestamp.add(periodFinish.sub(lastUpdateTime));
             *
             * If we have not reached the end yet, we must extend it by adding to it the difference between
             * the current timestamp and the last update (the period where the supply has been empty), i.e.:
             *
             * periodFinish = periodFinish.add(block.timestamp.sub(lastUpdateTime));
             *
             * Both formulas are equivalent.
             */
            periodFinish = periodFinish + block.timestamp - lastUpdateTime;
        }
    }

    function _updateReward() internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
    }

    function _updateAccountReward(address account) internal {
        _updateReward();

        assert(account != address(0));

        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
    }
}
