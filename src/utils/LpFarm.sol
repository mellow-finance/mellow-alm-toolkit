// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/ILpStaker.sol";
import "./AccessControlCalls.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

import "src/interfaces/external/velo/IRewardsDistributor.sol";
import "src/interfaces/external/velo/IVoter.sol";
import "src/interfaces/external/velo/IVotingEscrow.sol";

contract LpFarm is ERC20Upgradeable, ReentrancyGuard, AccessControlCalls {
    using SafeERC20 for IERC20;
    using Math for uint256;

    struct LpWrapperPosition {
        uint256 lpAmount;
        uint256 growthInsideLastX128;
    }

    /// @dev Thrown when an amount provided is zero
    error ZeroAmount();

    ICore public immutable core;
    IOracle public immutable oracle;
    IAmmModule public immutable ammModule;
    IVoter public immutable voter = IVoter(0x41C914ee0c7E1A5edCD0295623e6dC557B5aBf3C);
    IVotingEscrow public immutable votingEscrow; // = IVotingEscrow(0xFAf8FD17D9840595845582fCB047DF13f006787d);
    IRewardsDistributor public immutable rewardsDistributor;
    address public feesVotingReward;

    ILpWrapper public lpWrapper;
    address public rewardToken;
    address public token0;
    address public token1;
    uint256 public veNFT;
    uint256 public lpPrice;
    uint256 public lpWrapperPositionGrowthInsideLastX128;
    mapping(address => LpWrapperPosition) private lpWrapperPosition;

    bytes32 public constant OPERATOR_ROLE = keccak256("utils.LpFarm.OPERATOR_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("utils.LpFarm.MANAGER_ROLE");
    uint256 public constant Q128 = 2 ** 128;

    constructor(address core_) {
        if (core_ == address(0)) {
            revert AddressZero();
        }
        core = ICore(core_);
        oracle = core.oracle();
        ammModule = core.ammModule();
        votingEscrow = voter.ve();
        rewardsDistributor = IRewardsDistributor(votingEscrow.distributor());
    }

    function initialize(
        ILpWrapper lpWrapper_,
        address admin_,
        address operator_,
        uint256 initialSupply_
    ) external initializer {
        if (address(lpWrapper_) == address(0) || admin_ == address(0) || operator_ == address(0)) {
            revert AddressZero();
        }
        if (initialSupply_ == 0) {
            revert ZeroAmount();
        }
        __AccessControlCalls_init(admin_);

        _grantRole(OPERATOR_ROLE, operator_);
        _grantRole(MANAGER_ROLE, admin_);

        __ERC20_init(
            string(abi.encodePacked("Farmed ", IERC20Metadata(address(lpWrapper_)).name())),
            string(abi.encodePacked("fm", IERC20Metadata(address(lpWrapper_)).symbol()))
        );

        lpWrapper = lpWrapper_;
        rewardToken = lpWrapper_.rewardToken();
        token0 = lpWrapper_.token0();
        token1 = lpWrapper_.token1();
        lpPrice = 1 ether;

        IERC20(address(rewardToken)).approve(address(votingEscrow), type(uint256).max);
        IERC20(address(token0)).approve(address(lpWrapper_), type(uint256).max);
        IERC20(address(token1)).approve(address(lpWrapper_), type(uint256).max);

        address pool = lpWrapper_.pool();
        veNFT = _createInitialLock(initialSupply_, pool);
        feesVotingReward = voter.gaugeToFees(ICLPool(pool).gauge());
    }

    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) {
            revert ZeroAmount();
        }
        address sender = msg.sender;
        IERC20(address(rewardToken)).safeTransferFrom(sender, address(this), amount);

        _mintShares(sender, amount);
    }

    function rebase() public /* nonReentrant onlyRole(OPERATOR_ROLE) */ {
        uint256 veNFT_ = veNFT;
        address this_ = address(this);

        rewardsDistributor.claim(veNFT_);
        lpWrapper.getRewards(this_);
        uint256 rewardBalance = IERC20(address(rewardToken)).balanceOf(this_);

        if (rewardBalance > 0) {
            votingEscrow.increaseAmount(veNFT_, rewardBalance);
        }
        lpPrice = votingEscrow.balanceOfNFT(veNFT_).mulDiv(1 ether, totalSupply());

        address[] memory _fees = new address[](1);
        _fees[0] = feesVotingReward;
        address[][] memory _tokens = new address[][](1);
        _tokens[0] = new address[](2);
        _tokens[0][0] = token0;
        _tokens[0][1] = token1;
        voter.claimFees(_fees, _tokens, veNFT_);
        uint256 token0Balance = IERC20(token0).balanceOf(this_);
        uint256 token1Balance = IERC20(token1).balanceOf(this_);
        uint256 lpDeltaAmount = lpWrapper.previewDeposit(token0Balance, token1Balance);
        if (lpDeltaAmount == 0) {
            return;
        }
        (,, lpDeltaAmount) = lpWrapper.mint(
            ILpWrapper.MintParams({
                lpAmount: lpDeltaAmount,
                amount0Max: token0Balance,
                amount1Max: token1Balance,
                recipient: this_,
                deadline: block.timestamp + 1 hours
            })
        );
        lpWrapperPositionGrowthInsideLastX128 += lpDeltaAmount.mulDiv(Q128, totalSupply());
    }

    function _mintShares(address to, uint256 amount) internal returns (uint256 shares) {
        /// @dev Collect rewards and increaseAmount lock before updating the position to update lpPrice
        rebase();

        /// @dev Update the position of the user
        LpWrapperPosition memory lpWrapperPosition_ = lpWrapperPosition[to];
        uint256 growthInsideX128 =
            lpWrapperPositionGrowthInsideLastX128 - lpWrapperPosition_.growthInsideLastX128;
        lpWrapperPosition_.lpAmount += lpWrapperPosition_.lpAmount.mulDiv(growthInsideX128, Q128);

        /// @dev increaseAmount lock and mint shares
        votingEscrow.increaseAmount(veNFT, amount);
        shares = amount.mulDiv(1 ether, lpPrice);
        _mint(to, shares);
        lpWrapperPosition[to] = lpWrapperPosition_;
    }

    function _createInitialLock(uint256 initialSupply, address pool)
        internal
        returns (uint256 tokenId)
    {
        if (veNFT != 0) {
            revert("Initial lock already created");
        }
        address sender = msg.sender;
        IERC20(address(rewardToken)).safeTransferFrom(sender, address(this), initialSupply);
        tokenId = votingEscrow.createLock(initialSupply, 4 * 365 days);
        votingEscrow.lockPermanent(tokenId);

        address[] memory poolVote = new address[](1);
        uint256[] memory weights = new uint256[](1);

        poolVote[0] = pool;
        weights[0] = 1 ether;

        voter.vote(tokenId, poolVote, weights);

        _mint(sender, initialSupply);
    }
}
