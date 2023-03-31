// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "./IFeeCollector.sol";
import "./ILiquityBase.sol";
import "./IRToken.sol";

/// @dev Max fee percentage must be between borrowing spread and 100%.
error PositionManagerInvalidMaxFeePercentage();

/// @dev Position is active.
error PositionMaangerPositionActive();

/// @dev Max fee percentage must be between 0.5% and 100%.
error PositionManagerMaxFeePercentageOutOfRange();

/// @dev Position is not active (either does not exist or closed).
error PositionManagerPositionNotActive();

/// @dev Requested redemption amount is > user's R token balance.
error PositionManagerRedemptionAmountExceedsBalance();

/// @dev Only one position in the system.
error PositionManagerOnlyOnePositionInSystem();

/// @dev Amount is zero.
error PositionManagerAmountIsZero();

/// @dev Nothing to liquidate.
error NothingToLiquidate();

/// @dev Unable to redeem any amount.
error UnableToRedeemAnyAmount();

/// @dev Position array must is empty.
error PositionArrayEmpty();

/// @dev Fee would eat up all returned collateral.
error FeeEatsUpAllReturnedCollateral();

/// @dev Borrowing spread exceeds maximum.
error BorrowingSpreadExceedsMaximum();

/// @dev Debt increase requires non-zero debt change.
error DebtIncreaseZeroDebtChange();

/// @dev Cannot withdraw and add collateral at the same time.
error NotSingularCollateralChange();

/// @dev There must be either a collateral change or a debt change.
error NoCollateralOrDebtChange();

/// @dev An operation that would result in ICR < MCR is not permitted.
error NewICRLowerThanMCR(uint256 newICR);

/// @dev Position's net debt must be greater than minimum.
error NetDebtBelowMinimum(uint256 netDebt);

/// @dev Amount repaid must not be larger than the Position's debt.
error RepayRAmountExceedsDebt(uint256 debt);

/// @dev Caller doesn't have enough R to make repayment.
error RepayNotEnoughR();

/// @dev The provided Liquidation Protocol Fee is out of the allowed bound.
error LiquidationProtocolFeeOutOfBound();

// Common interface for the Position Manager.
interface IPositionManager is ILiquityBase, IFeeCollector {
    enum PositionStatus {
        nonExistent,
        active,
        closedByOwner,
        closedByLiquidation,
        closedByRedemption
    }

    enum PositionManagerOperation {
        applyPendingRewards,
        liquidate,
        redeemCollateral,
        openPosition,
        closePosition,
        adjustPosition
    }

    // --- Events ---

    event PositionManagerDeployed(
        IPriceFeed _priceFeed,
        IERC20 _collateralToken,
        IRToken _rToken,
        address _feeRecipient
    );

    event LiquidationProtocolFeeChanged(uint256 _liquidationProtocolFee);

    event Liquidation(uint _liquidatedDebt, uint _liquidatedColl, uint _liquidationProtocolFee, uint _collGasCompensation, uint _RGasCompensation);
    event Redemption(uint _attemptedRAmount, uint _actualRAmount, uint _collateralTokenSent, uint _collateralTokenFee);
    event PositionUpdated(address indexed _borrower, uint _debt, uint _coll, uint _stake, PositionManagerOperation _operation);
    event PositionLiquidated(address indexed _borrower, uint _debt, uint _coll, PositionManagerOperation _operation);
    event BorrowingSpreadUpdated(uint256 _borrowingSpread);
    event BaseRateUpdated(uint _baseRate);
    event LastFeeOpTimeUpdated(uint _lastFeeOpTime);
    event TotalStakesUpdated(uint _newTotalStakes);
    event SystemSnapshotsUpdated(uint _totalStakesSnapshot, uint _totalCollateralSnapshot);
    event LTermsUpdated(uint _L_CollateralBalance, uint _L_RDebt);
    event PositionSnapshotsUpdated(uint _L_CollateralBalance, uint _L_RDebt);
    event PositionCreated(address indexed _borrower);
    event RBorrowingFeePaid(address indexed _borrower, uint _rFee);

    // --- Functions ---

    function setLiquidationProtocolFee(uint256 _liquidationProtocolFee) external;
    function liquidationProtocolFee() external view returns (uint256);
    function MAX_BORROWING_SPREAD() external view returns (uint256);
    function MAX_LIQUIDATION_PROTOCOL_FEE() external view returns (uint256);
    function collateralToken() external view returns (IERC20);
    function rToken() external view returns (IRToken);

    function positions(
        address _borrower
    ) external view returns (uint debt, uint coll, uint stake, PositionStatus status);

    function sortedPositions() external view returns (address first, address last, uint256 maxSize, uint256 size);

    function sortedPositionsNodes(address _id) external view returns(bool exists, address nextId, address prevId);

    function getNominalICR(address _borrower) external view returns (uint);
    function getCurrentICR(address _borrower, uint _price) external view returns (uint);

    function liquidate(address _borrower) external;
    function batchLiquidatePositions(address[] calldata _positionArray) external;

    function redeemCollateral(
        uint _rAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint _partialRedemptionHintNICR,
        uint _maxIterations,
        uint _maxFee
    ) external;

    function getPendingCollateralTokenReward(address _borrower) external view returns (uint);

    function getPendingRDebtReward(address _borrower) external view returns (uint);

    function hasPendingRewards(address _borrower) external view returns (bool);

    function getEntireDebtAndColl(address _borrower) external view returns (
        uint debt,
        uint coll,
        uint pendingRDebtReward,
        uint pendingCollateralTokenReward
    );

    function getRedemptionRate() external view returns (uint);
    function getRedemptionRateWithDecay() external view returns (uint);

    function getRedemptionFeeWithDecay(uint _collateralTokenDrawn) external view returns (uint);

    function borrowingSpread() external view returns (uint256);
    function setBorrowingSpread(uint256 _borrowingSpread) external;

    function getBorrowingRate() external view returns (uint);
    function getBorrowingRateWithDecay() external view returns (uint);

    function getBorrowingFee(uint rDebt) external view returns (uint);
    function getBorrowingFeeWithDecay(uint _rDebt) external view returns (uint);

    function openPosition(uint _maxFee, uint _rAmount, address _upperHint, address _lowerHint, uint _amount) external;

    function addColl(address _upperHint, address _lowerHint, uint _amount) external;

    function withdrawColl(uint _amount, address _upperHint, address _lowerHint) external;

    function withdrawR(uint _maxFee, uint _amount, address _upperHint, address _lowerHint) external;

    function repayR(uint _amount, address _upperHint, address _lowerHint) external;

    function closePosition() external;

    function adjustPosition(uint _maxFee, uint _collWithdrawal, uint _debtChange, bool isDebtIncrease, address _upperHint, address _lowerHint, uint _amount) external;

    function getCompositeDebt(uint _debt) external pure returns (uint);
}