pragma solidity 0.8.4;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/IAccessControlEnumerable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


interface IAbstractRewards {
	/**
	 * @dev Returns the total amount of rewards a given address is able to withdraw.
	 * @param account Address of a reward recipient
	 * @return A uint256 representing the rewards `account` can withdraw
	 */
	function withdrawableRewardsOf(address account) external view returns (uint256);

  /**
	 * @dev View the amount of funds that an address has withdrawn.
	 * @param account The address of a token holder.
	 * @return The amount of funds that `account` has withdrawn.
	 */
	function withdrawnRewardsOf(address account) external view returns (uint256);

	/**
	 * @dev View the amount of funds that an address has earned in total.
	 * accumulativeFundsOf(account) = withdrawableRewardsOf(account) + withdrawnRewardsOf(account)
	 * = (pointsPerShare * balanceOf(account) + pointsCorrection[account]) / POINTS_MULTIPLIER
	 * @param account The address of a token holder.
	 * @return The amount of funds that `account` has earned in total.
	 */
	function cumulativeRewardsOf(address account) external view returns (uint256);

	/**
	 * @dev This event emits when new funds are distributed
	 * @param by the address of the sender who distributed funds
	 * @param rewardsDistributed the amount of funds received for distribution
	 */
	event RewardsDistributed(address indexed by, uint256 rewardsDistributed);

	/**
	 * @dev This event emits when distributed funds are withdrawn by a token holder.
	 * @param by the address of the receiver of funds
	 * @param fundsWithdrawn the amount of funds that were withdrawn
	 */
	event RewardsWithdrawn(address indexed by, uint256 fundsWithdrawn);
}

abstract contract AbstractRewards is IAbstractRewards {
  using SafeCast for uint128;
  using SafeCast for uint256;
  using SafeCast for int256;

/* ========  Constants  ======== */
  uint128 public constant POINTS_MULTIPLIER = type(uint128).max;

/* ========  Internal Function References  ======== */
  function(address) view returns (uint256) private immutable getSharesOf;
  function() view returns (uint256) private immutable getTotalShares;

/* ========  Storage  ======== */
  uint256 public pointsPerShare;
  mapping(address => int256) public pointsCorrection;
  mapping(address => uint256) public withdrawnRewards;

  constructor(
    function(address) view returns (uint256) getSharesOf_,
    function() view returns (uint256) getTotalShares_
  ) {
    getSharesOf = getSharesOf_;
    getTotalShares = getTotalShares_;
  }

/* ========  Public View Functions  ======== */
  /**
   * @dev Returns the total amount of rewards a given address is able to withdraw.
   * @param _account Address of a reward recipient
   * @return A uint256 representing the rewards `account` can withdraw
   */
  function withdrawableRewardsOf(address _account) public view override returns (uint256) {
    return cumulativeRewardsOf(_account) - withdrawnRewards[_account];
  }

  /**
   * @notice View the amount of rewards that an address has withdrawn.
   * @param _account The address of a token holder.
   * @return The amount of rewards that `account` has withdrawn.
   */
  function withdrawnRewardsOf(address _account) public view override returns (uint256) {
    return withdrawnRewards[_account];
  }

  /**
   * @notice View the amount of rewards that an address has earned in total.
   * @dev accumulativeFundsOf(account) = withdrawableRewardsOf(account) + withdrawnRewardsOf(account)
   * = (pointsPerShare * balanceOf(account) + pointsCorrection[account]) / POINTS_MULTIPLIER
   * @param _account The address of a token holder.
   * @return The amount of rewards that `account` has earned in total.
   */
  function cumulativeRewardsOf(address _account) public view override returns (uint256) {
    return ((pointsPerShare * getSharesOf(_account)).toInt256() + pointsCorrection[_account]).toUint256() / POINTS_MULTIPLIER;
  }

/* ========  Dividend Utility Functions  ======== */

  /** 
   * @notice Distributes rewards to token holders.
   * @dev It reverts if the total shares is 0.
   * It emits the `RewardsDistributed` event if the amount to distribute is greater than 0.
   * About undistributed rewards:
   *   In each distribution, there is a small amount which does not get distributed,
   *   which is `(amount * POINTS_MULTIPLIER) % totalShares()`.
   *   With a well-chosen `POINTS_MULTIPLIER`, the amount of funds that are not getting
   *   distributed in a distribution can be less than 1 (base unit).
   */
  function _distributeRewards(uint256 _amount) internal {
    uint256 shares = getTotalShares();
    require(shares > 0, "AbstractRewards._distributeRewards: total share supply is zero");

    if (_amount > 0) {
      pointsPerShare = pointsPerShare + (_amount * POINTS_MULTIPLIER / shares);
      emit RewardsDistributed(msg.sender, _amount);
    }
  }

  /**
   * @notice Prepares collection of owed rewards
   * @dev It emits a `RewardsWithdrawn` event if the amount of withdrawn rewards is
   * greater than 0.
   */
  function _prepareCollect(address _account) internal returns (uint256) {
    uint256 _withdrawableDividend = withdrawableRewardsOf(_account);
    if (_withdrawableDividend > 0) {
      withdrawnRewards[_account] = withdrawnRewards[_account] + _withdrawableDividend;
      emit RewardsWithdrawn(_account, _withdrawableDividend);
    }
    return _withdrawableDividend;
  }

  function _correctPointsForTransfer(address _from, address _to, uint256 _shares) internal {
    int256 _magCorrection = (pointsPerShare * _shares).toInt256();
    pointsCorrection[_from] = pointsCorrection[_from] + _magCorrection;
    pointsCorrection[_to] = pointsCorrection[_to] - _magCorrection;
  }

  /**
   * @dev Increases or decreases the points correction for `account` by
   * `shares*pointsPerShare`.
   */
  function _correctPoints(address _account, int256 _shares) internal {
    pointsCorrection[_account] = pointsCorrection[_account] + (_shares * (int256(pointsPerShare)));
  }
}

contract TokenSaver is AccessControlEnumerable {
    using SafeERC20 for IERC20;

    bytes32 public constant TOKEN_SAVER_ROLE = keccak256("TOKEN_SAVER_ROLE");

    event TokenSaved(address indexed by, address indexed receiver, address indexed token, uint256 amount);

    modifier onlyTokenSaver() {
        require(hasRole(TOKEN_SAVER_ROLE, _msgSender()), "TokenSaver.onlyTokenSaver: permission denied");
        _;
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function saveToken(address _token, address _receiver, uint256 _amount) external onlyTokenSaver {
        IERC20(_token).safeTransfer(_receiver, _amount);
        emit TokenSaved(_msgSender(), _receiver, _token, _amount);
    }

}

interface IBasePool {
    function distributeRewards(uint256 _amount) external;
}

abstract contract BasePool is ERC20Votes, AbstractRewards, IBasePool, TokenSaver {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for int256;

    IERC20 public immutable depositToken;
    IERC20 public immutable rewardToken;
    ITimeLockPool public immutable escrowPool;
    uint256 public immutable escrowPortion; // how much is escrowed 1e18 == 100%
    uint256 public immutable escrowDuration; // escrow duration in seconds

    event RewardsClaimed(address indexed _from, address indexed _receiver, uint256 _escrowedAmount, uint256 _nonEscrowedAmount);

    constructor(
        string memory _name,
        string memory _symbol,
        address _depositToken,
        address _rewardToken,
        address _escrowPool,
        uint256 _escrowPortion,
        uint256 _escrowDuration
    ) ERC20Permit(_name) ERC20(_name, _symbol) AbstractRewards(balanceOf, totalSupply) {
        require(_escrowPortion <= 1e18, "BasePool.constructor: Cannot escrow more than 100%");
        require(_depositToken != address(0), "BasePool.constructor: Deposit token must be set");
        require(_rewardToken != address(0), "BasePool.constructor: Reward token must be set");
        depositToken = IERC20(_depositToken);
        rewardToken = IERC20(_rewardToken);
        escrowPool = ITimeLockPool(_escrowPool);
        escrowPortion = _escrowPortion;
        escrowDuration = _escrowDuration;

        if(_escrowPool != address(0)) {
            IERC20(_rewardToken).safeApprove(_escrowPool, type(uint256).max);
        }
    }

    function _mint(address _account, uint256 _amount) internal virtual override {
		super._mint(_account, _amount);
        _correctPoints(_account, -(_amount.toInt256()));
	}
	
	function _burn(address _account, uint256 _amount) internal virtual override {
		super._burn(_account, _amount);
        _correctPoints(_account, _amount.toInt256());
	}

    function _transfer(address _from, address _to, uint256 _value) internal virtual override {
		super._transfer(_from, _to, _value);
        _correctPointsForTransfer(_from, _to, _value);
	}

    function distributeRewards(uint256 _amount) external override {
        rewardToken.safeTransferFrom(_msgSender(), address(this), _amount);
        _distributeRewards(_amount);
    }

    function claimRewards(address _receiver) external {
        uint256 rewardAmount = _prepareCollect(_msgSender());
        uint256 escrowedRewardAmount = rewardAmount * escrowPortion / 1e18;
        uint256 nonEscrowedRewardAmount = rewardAmount - escrowedRewardAmount;

        if(escrowedRewardAmount != 0 && address(escrowPool) != address(0)) {
            escrowPool.deposit(escrowedRewardAmount, escrowDuration, _receiver);
        }

        // ignore dust
        if(nonEscrowedRewardAmount > 1) {
            rewardToken.safeTransfer(_receiver, nonEscrowedRewardAmount);
        }

        emit RewardsClaimed(_msgSender(), _receiver, escrowedRewardAmount, nonEscrowedRewardAmount);
    }

}
