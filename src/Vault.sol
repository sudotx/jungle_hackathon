// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

import {Strategy, ERC20Strategy} from "./interfaces/Strategy.sol";

import {VaultFactory} from "./VaultFactory.sol";

contract Vault is ERC4626, ReentrancyGuard {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using SafeCastLib for uint256;

    /// @notice The percentage of profit recognized each harvest to reserve as fees.
    /// @dev A fixed point number where 1e18 represents 100% and 0 represents 0%.
    uint256 public feePercent;

    /// @notice The period in seconds during which multiple harvests can occur
    /// regardless if they are taking place before the harvest delay has elapsed.
    /// @dev Long harvest windows open the Vault up to profit distribution slowdown attacks.
    uint128 public harvestWindow;

    /// @notice The period in seconds over which locked profit is unlocked.
    /// @dev Cannot be 0 as it opens harvests up to sandwich attacks.
    uint64 public harvestDelay;

    /// @notice The value that will replace harvestDelay next harvest.
    /// @dev In the case that the next delay is 0, no update will be applied.
    uint64 public nextHarvestDelay;

    /// @notice The desired percentage of the Vault's holdings to keep as float.
    /// @dev A fixed point number where 1e18 represents 100% and 0 represents 0%.
    uint256 public targetFloatPercent;

    /// @notice Whether the Vault should treat the underlying token as WETH compatible.
    /// @dev If enabled the Vault will allow trusting strategies that accept Ether.
    bool public underlyingIsWETH;

    /// @notice The total amount of underlying tokens held in strategies at the time of the last harvest.
    /// @dev Includes maxLockedProfit, must be correctly subtracted to compute available/free holdings.
    uint256 public totalStrategyHoldings;

    /// @notice A timestamp representing when the first harvest in the most recent harvest window occurred.
    /// @dev May be equal to lastHarvest if there was/has only been one harvest in the most last/current window.
    uint64 public lastHarvestWindowStart;

    /// @notice A timestamp representing when the most recent harvest occurred.
    uint64 public lastHarvest;

    /// @notice The amount of locked profit at the end of the last harvest.
    uint128 public maxLockedProfit;

    /// @notice The percentage of profit recognized each harvest to reserve as fees.
    /// @dev A fixed point number where 1e18 represents 100% and 0 represents 0%.
    uint256 public feePercent;

    /// @dev Packed struct of strategy data.
    /// @param trusted Whether the strategy is trusted.
    /// @param balance The amount of underlying tokens held in the strategy.
    struct StrategyData {
        // Used to determine if the Vault will operate on a strategy.
        bool trusted;
        // Used to determine profit and loss during harvests of the strategy.
        uint248 balance;
    }

    /// @notice Maps strategies to data the Vault holds on them.
    mapping(Strategy => StrategyData) public getStrategyData;

    /// @notice The period in seconds during which multiple harvests can occur
    /// regardless if they are taking place before the harvest delay has elapsed.
    /// @dev Long harvest windows open the Vault up to profit distribution slowdown attacks.
    uint128 public harvestWindow;

    /// @notice The period in seconds over which locked profit is unlocked.
    /// @dev Cannot be 0 as it opens harvests up to sandwich attacks.
    uint64 public harvestDelay;

    /// @notice The value that will replace harvestDelay next harvest.
    /// @dev In the case that the next delay is 0, no update will be applied.
    uint64 public nextHarvestDelay;

    /// @notice The desired percentage of the Vault's holdings to keep as float.
    /// @dev A fixed point number where 1e18 represents 100% and 0 represents 0%.
    uint256 public targetFloatPercent;

    /// @notice Whether the Vault should treat the underlying token as WETH compatible.
    /// @dev If enabled the Vault will allow trusting strategies that accept Ether.
    bool public underlyingIsWETH;

    /// @notice Whether the Vault has been initialized yet.
    /// @dev Can go from false to true, never from true to false.
    bool public isInitialized;

    /// @notice Emitted when the Vault is initialized.
    /// @param user The authorized user who triggered the initialization.
    event Initialized(address indexed user);

    /// @notice Emitted after fees are claimed.
    /// @param user The authorized user who claimed the fees.
    /// @param rvTokenAmount The amount of rvTokens that were claimed.
    event FeesClaimed(address indexed user, uint256 rvTokenAmount);

    /// @notice Emitted after the Vault deposits into a strategy contract.
    /// @param user The authorized user who triggered the deposit.
    /// @param strategy The strategy that was deposited into.
    /// @param underlyingAmount The amount of underlying tokens that were deposited.
    event StrategyDeposit(address indexed user, Strategy indexed strategy, uint256 underlyingAmount);

    /// @notice Emitted after the Vault withdraws funds from a strategy contract.
    /// @param user The authorized user who triggered the withdrawal.
    /// @param strategy The strategy that was withdrawn from.
    /// @param underlyingAmount The amount of underlying tokens that were withdrawn.
    event StrategyWithdrawal(address indexed user, Strategy indexed strategy, uint256 underlyingAmount);

    /// @notice Emitted after a successful harvest.
    /// @param user The authorized user who triggered the harvest.
    /// @param strategies The trusted strategies that were harvested.
    event Harvest(address indexed user, Strategy[] strategies);

    /// @notice Emitted when the fee percentage is updated.
    /// @param user The authorized user who triggered the update.
    /// @param newFeePercent The new fee percentage.
    event FeePercentUpdated(address indexed user, uint256 newFeePercent);

    /// @notice Emitted when the harvest window is updated.
    /// @param user The authorized user who triggered the update.
    /// @param newHarvestWindow The new harvest window.
    event HarvestWindowUpdated(address indexed user, uint128 newHarvestWindow);

    /// @notice Emitted when the harvest delay is updated.
    /// @param user The authorized user who triggered the update.
    /// @param newHarvestDelay The new harvest delay.
    event HarvestDelayUpdated(address indexed user, uint64 newHarvestDelay);

    /// @notice Emitted when the harvest delay is scheduled to be updated next harvest.
    /// @param user The authorized user who triggered the update.
    /// @param newHarvestDelay The scheduled updated harvest delay.
    event HarvestDelayUpdateScheduled(address indexed user, uint64 newHarvestDelay);

    /// @notice Emitted when the target float percentage is updated.
    /// @param user The authorized user who triggered the update.
    /// @param newTargetFloatPercent The new target float percentage.
    event TargetFloatPercentUpdated(address indexed user, uint256 newTargetFloatPercent);

    /// @notice Emitted when whether the Vault should treat the underlying as WETH is updated.
    /// @param user The authorized user who triggered the update.
    /// @param newUnderlyingIsWETH Whether the Vault nows treats the underlying as WETH.
    event UnderlyingIsWETHUpdated(address indexed user, bool newUnderlyingIsWETH);

    /// @notice Emitted after a successful harvest.
    /// @param user The authorized user who triggered the harvest.
    /// @param strategies The trusted strategies that were harvested.
    event Harvest(address indexed user, Strategy[] strategies);

    /// @notice Emitted after the Vault deposits into a strategy contract.
    /// @param user The authorized user who triggered the deposit.
    /// @param strategy The strategy that was deposited into.
    /// @param underlyingAmount The amount of underlying tokens that were deposited.
    event StrategyDeposit(address indexed user, Strategy indexed strategy, uint256 underlyingAmount);

    /// @notice Emitted after the Vault withdraws funds from a strategy contract.
    /// @param user The authorized user who triggered the withdrawal.
    /// @param strategy The strategy that was withdrawn from.
    /// @param underlyingAmount The amount of underlying tokens that were withdrawn.
    event StrategyWithdrawal(address indexed user, Strategy indexed strategy, uint256 underlyingAmount);

    /// @notice Emitted after fees are claimed.
    /// @param user The authorized user who claimed the fees.
    /// @param rvTokenAmount The amount of rvTokens that were claimed.
    event FeesClaimed(address indexed user, uint256 rvTokenAmount);

    /// @notice Emitted when the Vault is initialized.
    /// @param user The authorized user who triggered the initialization.
    event Initialized(address indexed user);

    /*///////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The maximum number of elements allowed on the withdrawal stack.
    /// @dev Needed to prevent denial of service attacks by queue operators.
    uint256 internal constant MAX_WITHDRAWAL_STACK_SIZE = 32;

    /*///////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The underlying token the Vault accepts.
    ERC20 public immutable UNDERLYING;

    /// @notice The base unit of the underlying token and hence rvToken.
    /// @dev Equal to 10 ** decimals. Used for fixed point arithmetic.
    uint256 internal immutable BASE_UNIT;

    constructor(ERC20 _underlyingToken, string memory _name, string memory _symbol)
        ERC4626(
            _underlyingToken,
            // ex: Rari Dai Stablecoin Vault
            string(abi.encodePacked("Hackathon ", _underlyingToken.name(), " Vault")),
            // ex: rvDAI
            string(abi.encodePacked("shared", _underlyingToken.symbol()))
        )
    {
        UNDERLYING = _underlyingToken;

        BASE_UNIT = 10 ** decimals;

        // Prevent minting of rvTokens until
        // the initialize function is called.
        totalSupply = type(uint256).max;
    }

    // fee configuration
    /// @notice Sets a new fee percentage.
    /// @param newFeePercent The new fee percentage.
    function setFeePercent(uint256 newFeePercent) external requiresAuth {
        // A fee percentage over 100% doesn't make sense.
        require(newFeePercent <= 1e18, "FEE_TOO_HIGH");

        // Update the fee percentage.
        feePercent = newFeePercent;

        emit FeePercentUpdated(msg.sender, newFeePercent);
    }
    // harvest configuration
    /// @notice Sets a new harvest window.
    /// @param newHarvestWindow The new harvest window.
    /// @dev The Vault's harvestDelay must already be set before calling.

    function setHarvestWindow(uint128 newHarvestWindow) external requiresAuth {
        // A harvest window longer than the harvest delay doesn't make sense.
        require(newHarvestWindow <= harvestDelay, "WINDOW_TOO_LONG");

        // Update the harvest window.
        harvestWindow = newHarvestWindow;

        emit HarvestWindowUpdated(msg.sender, newHarvestWindow);
    }

    /// @notice Sets a new harvest delay.
    /// @param newHarvestDelay The new harvest delay to set.
    /// @dev If the current harvest delay is 0, meaning it has not
    /// been set before, it will be updated immediately, otherwise
    /// it will be scheduled to take effect after the next harvest.
    function setHarvestDelay(uint64 newHarvestDelay) external requiresAuth {
        // A harvest delay of 0 makes harvests vulnerable to sandwich attacks.
        require(newHarvestDelay != 0, "DELAY_CANNOT_BE_ZERO");

        // A harvest delay longer than 1 year doesn't make sense.
        require(newHarvestDelay <= 365 days, "DELAY_TOO_LONG");

        // If the harvest delay is 0, meaning it has not been set before:
        if (harvestDelay == 0) {
            // We'll apply the update immediately.
            harvestDelay = newHarvestDelay;

            emit HarvestDelayUpdated(msg.sender, newHarvestDelay);
        } else {
            // We'll apply the update next harvest.
            nextHarvestDelay = newHarvestDelay;

            emit HarvestDelayUpdateScheduled(msg.sender, newHarvestDelay);
        }
    }

    // target float configuration
    /// @notice Set a new target float percentage.
    /// @param newTargetFloatPercent The new target float percentage.
    function setTargetFloatPercent(uint256 newTargetFloatPercent) external requiresAuth {
        // A target float percentage over 100% doesn't make sense.
        require(newTargetFloatPercent <= 1e18, "TARGET_TOO_HIGH");

        // Update the target float percentage.
        targetFloatPercent = newTargetFloatPercent;

        emit TargetFloatPercentUpdated(msg.sender, newTargetFloatPercent);
    }

    // underlying is weth configuration
    /// @notice Sets whether the Vault treats the underlying as WETH.
    /// @param newUnderlyingIsWETH Whether the Vault should treat the underlying as WETH.
    /// @dev The underlying token must have 18 decimals, to match Ether's decimal scheme.
    function setUnderlyingIsWETH(bool newUnderlyingIsWETH) external requiresAuth {
        // Ensure the underlying token's decimals match ETH if is WETH being set to true.
        require(!newUnderlyingIsWETH || UNDERLYING.decimals() == 18, "WRONG_DECIMALS");

        // Update whether the Vault treats the underlying as WETH.
        underlyingIsWETH = newUnderlyingIsWETH;

        emit UnderlyingIsWETHUpdated(msg.sender, newUnderlyingIsWETH);
    }
    // withdrawal stack storage
    /// @notice Gets the full withdrawal stack.
    /// @return An ordered array of strategies representing the withdrawal stack.
    /// @dev This is provided because Solidity converts public arrays into index getters,
    /// but we need a way to allow external contracts and users to access the whole array.

    function getWithdrawalStack() external view returns (Strategy[] memory) {
        return withdrawalStack;
    }

    // deposit and withdrawal storage
    // 4626 overrides

    function afterDeposit(uint256, uint256) internal override {}

    function beforeWithdraw(uint256 assets, uint256) internal override {
        // Retrieve underlying tokens from strategies/float.
        retrieveUnderlying(assets);
    }

    /// @dev Retrieves a specific amount of underlying tokens held in strategies and/or float.
    /// @dev Only withdraws from strategies if needed and maintains the target float percentage if possible.
    /// @param underlyingAmount The amount of underlying tokens to retrieve.
    function retrieveUnderlying(uint256 underlyingAmount) internal {
        // Get the Vault's floating balance.
        uint256 float = totalFloat();

        // If the amount is greater than the float, withdraw from strategies.
        if (underlyingAmount > float) {
            // Compute the amount needed to reach our target float percentage.
            uint256 floatMissingForTarget = (totalAssets() - underlyingAmount).mulWadDown(targetFloatPercent);

            // Compute the bare minimum amount we need for this withdrawal.
            uint256 floatMissingForWithdrawal = underlyingAmount - float;

            // Pull enough to cover the withdrawal and reach our target float percentage.
            pullFromWithdrawalStack(floatMissingForWithdrawal + floatMissingForTarget);
        }
    }

    // vault accounting storage
    /// @notice Calculates the total amount of underlying tokens the Vault holds.
    /// @return totalUnderlyingHeld The total amount of underlying tokens the Vault holds.
    function totalAssets() public view override returns (uint256 totalUnderlyingHeld) {
        unchecked {
            // Cannot underflow as locked profit can't exceed total strategy holdings.
            totalUnderlyingHeld = totalStrategyHoldings - lockedProfit();
        }

        // Include our floating balance in the total.
        totalUnderlyingHeld += totalFloat();
    }

    /// @notice Calculates the current amount of locked profit.
    /// @return The current amount of locked profit.
    function lockedProfit() public view returns (uint256) {
        // Get the last harvest and harvest delay.
        uint256 previousHarvest = lastHarvest;
        uint256 harvestInterval = harvestDelay;

        unchecked {
            // If the harvest delay has passed, there is no locked profit.
            // Cannot overflow on human timescales since harvestInterval is capped.
            if (block.timestamp >= previousHarvest + harvestInterval) return 0;

            // Get the maximum amount we could return.
            uint256 maximumLockedProfit = maxLockedProfit;

            // Compute how much profit remains locked based on the last harvest and harvest delay.
            // It's impossible for the previous harvest to be in the future, so this will never underflow.
            return maximumLockedProfit - (maximumLockedProfit * (block.timestamp - previousHarvest)) / harvestInterval;
        }
    }

    /// @notice Returns the amount of underlying tokens that idly sit in the Vault.
    /// @return The amount of underlying tokens that sit idly in the Vault.
    function totalFloat() public view returns (uint256) {
        return UNDERLYING.balanceOf(address(this));
    }

    /// @notice Calculates the total amount of underlying tokens the Vault holds.
    /// @return totalUnderlyingHeld The total amount of underlying tokens the Vault holds.
    function totalAssets() public view override returns (uint256 totalUnderlyingHeld) {
        unchecked {
            // Cannot underflow as locked profit can't exceed total strategy holdings.
            totalUnderlyingHeld = totalStrategyHoldings - lockedProfit();
        }

        // Include our floating balance in the total.
        totalUnderlyingHeld += totalFloat();
    }

    /// @notice Harvest a set of trusted strategies.
    /// @param strategies The trusted strategies to harvest.
    /// @dev Will always revert if called outside of an active
    /// harvest window or before the harvest delay has passed.
    function harvest(Strategy[] calldata strategies) external requiresAuth {
        // If this is the first harvest after the last window:
        if (block.timestamp >= lastHarvest + harvestDelay) {
            // Set the harvest window's start timestamp.
            // Cannot overflow 64 bits on human timescales.
            lastHarvestWindowStart = uint64(block.timestamp);
        } else {
            // We know this harvest is not the first in the window so we need to ensure it's within it.
            require(block.timestamp <= lastHarvestWindowStart + harvestWindow, "BAD_HARVEST_TIME");
        }

        // Get the Vault's current total strategy holdings.
        uint256 oldTotalStrategyHoldings = totalStrategyHoldings;

        // Used to store the total profit accrued by the strategies.
        uint256 totalProfitAccrued;

        // Used to store the new total strategy holdings after harvesting.
        uint256 newTotalStrategyHoldings = oldTotalStrategyHoldings;

        // Will revert if any of the specified strategies are untrusted.
        for (uint256 i = 0; i < strategies.length; i++) {
            // Get the strategy at the current index.
            Strategy strategy = strategies[i];

            // If an untrusted strategy could be harvested a malicious user could use
            // a fake strategy that over-reports holdings to manipulate the exchange rate.
            require(getStrategyData[strategy].trusted, "UNTRUSTED_STRATEGY");

            // Get the strategy's previous and current balance.
            uint256 balanceLastHarvest = getStrategyData[strategy].balance;
            uint256 balanceThisHarvest = strategy.balanceOfUnderlying(address(this));

            // Update the strategy's stored balance. Cast overflow is unrealistic.
            getStrategyData[strategy].balance = balanceThisHarvest.safeCastTo248();

            // Increase/decrease newTotalStrategyHoldings based on the profit/loss registered.
            // We cannot wrap the subtraction in parenthesis as it would underflow if the strategy had a loss.
            newTotalStrategyHoldings = newTotalStrategyHoldings + balanceThisHarvest - balanceLastHarvest;

            unchecked {
                // Update the total profit accrued while counting losses as zero profit.
                // Cannot overflow as we already increased total holdings without reverting.
                totalProfitAccrued += balanceThisHarvest > balanceLastHarvest
                    ? balanceThisHarvest - balanceLastHarvest // Profits since last harvest.
                    : 0; // If the strategy registered a net loss we don't have any new profit.
            }
        }

        // Compute fees as the fee percent multiplied by the profit.
        uint256 feesAccrued = totalProfitAccrued.mulDivDown(feePercent, 1e18);

        // If we accrued any fees, mint an equivalent amount of rvTokens.
        // Authorized users can claim the newly minted rvTokens via claimFees.
        _mint(address(this), feesAccrued.mulDivDown(BASE_UNIT, convertToAssets(BASE_UNIT)));

        // Update max unlocked profit based on any remaining locked profit plus new profit.
        maxLockedProfit = (lockedProfit() + totalProfitAccrued - feesAccrued).safeCastTo128();

        // Set strategy holdings to our new total.
        totalStrategyHoldings = newTotalStrategyHoldings;

        // Update the last harvest timestamp.
        // Cannot overflow on human timescales.
        lastHarvest = uint64(block.timestamp);

        emit Harvest(msg.sender, strategies);

        // Get the next harvest delay.
        uint64 newHarvestDelay = nextHarvestDelay;

        // If the next harvest delay is not 0:
        if (newHarvestDelay != 0) {
            // Update the harvest delay.
            harvestDelay = newHarvestDelay;

            // Reset the next harvest delay.
            nextHarvestDelay = 0;

            emit HarvestDelayUpdated(msg.sender, newHarvestDelay);
        }
    }

    /// @notice Deposit a specific amount of float into a trusted strategy.
    /// @param strategy The trusted strategy to deposit into.
    /// @param underlyingAmount The amount of underlying tokens in float to deposit.
    function depositIntoStrategy(Strategy strategy, uint256 underlyingAmount) external requiresAuth {
        // A strategy must be trusted before it can be deposited into.
        require(getStrategyData[strategy].trusted, "UNTRUSTED_STRATEGY");

        // Increase totalStrategyHoldings to account for the deposit.
        totalStrategyHoldings += underlyingAmount;

        unchecked {
            // Without this the next harvest would count the deposit as profit.
            // Cannot overflow as the balance of one strategy can't exceed the sum of all.
            getStrategyData[strategy].balance += underlyingAmount.safeCastTo248();
        }

        emit StrategyDeposit(msg.sender, strategy, underlyingAmount);

        // We need to deposit differently if the strategy takes ETH.
        if (strategy.isCEther()) {
            // Unwrap the right amount of WETH.
            WETH(payable(address(UNDERLYING))).withdraw(underlyingAmount);

            // Deposit into the strategy and assume it will revert on error.
            ETHStrategy(address(strategy)).mint{value: underlyingAmount}();
        } else {
            // Approve underlyingAmount to the strategy so we can deposit.
            UNDERLYING.safeApprove(address(strategy), underlyingAmount);

            // Deposit into the strategy and revert if it returns an error code.
            require(ERC20Strategy(address(strategy)).mint(underlyingAmount) == 0, "MINT_FAILED");
        }
    }

    /// @notice Withdraw a specific amount of underlying tokens from a strategy.
    /// @param strategy The strategy to withdraw from.
    /// @param underlyingAmount  The amount of underlying tokens to withdraw.
    /// @dev Withdrawing from a strategy will not remove it from the withdrawal stack.
    function withdrawFromStrategy(Strategy strategy, uint256 underlyingAmount) external requiresAuth {
        // A strategy must be trusted before it can be withdrawn from.
        require(getStrategyData[strategy].trusted, "UNTRUSTED_STRATEGY");

        // Without this the next harvest would count the withdrawal as a loss.
        getStrategyData[strategy].balance -= underlyingAmount.safeCastTo248();

        unchecked {
            // Decrease totalStrategyHoldings to account for the withdrawal.
            // Cannot underflow as the balance of one strategy will never exceed the sum of all.
            totalStrategyHoldings -= underlyingAmount;
        }

        emit StrategyWithdrawal(msg.sender, strategy, underlyingAmount);

        // Withdraw from the strategy and revert if it returns an error code.
        require(strategy.redeemUnderlying(underlyingAmount) == 0, "REDEEM_FAILED");

        // Wrap the withdrawn Ether into WETH if necessary.
        if (strategy.isCEther()) WETH(payable(address(UNDERLYING))).deposit{value: underlyingAmount}();
    }

    // initialize, destroy a vault //

    /// @notice Initializes the Vault, enabling it to receive deposits.
    /// @dev All critical parameters must already be set before calling.
    function initialize() external requiresAuth {
        // Ensure the Vault has not already been initialized.
        require(!isInitialized, "ALREADY_INITIALIZED");

        // Mark the Vault as initialized.
        isInitialized = true;

        // Open for deposits.
        totalSupply = 0;

        emit Initialized(msg.sender);
    }

    /// @notice Self destructs a Vault, enabling it to be redeployed.
    /// @dev Caller will receive any ETH held as float in the Vault.
    function destroy() external requiresAuth {
        selfdestruct(payable(msg.sender));
    }

    /*///////////////////////////////////////////////////////////////
                        RECIEVE ETHER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Required for the Vault to receive unwrapped ETH.
    receive() external payable {}
}
