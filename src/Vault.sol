// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// imports
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";


import {VaultFactory} from "./VaultFactory.sol";


contract Vault is ERC4626, ReentrancyGuard{
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    ERC20 public immutable override asset;

    error Error_InsufficientOutput();

    uint256 internal constant ONE = 10**18;


    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    /// @notice The recorded balance of the deposited asset.
    /// @dev This is used instead of asset.balanceOf(address(this)) to prevent attackers from
    /// atomically increasing the vault share value and thus exploiting integrated lending protocols.
    uint256 public assetBalance;



    // Functions
    constructor(ERC20 _token, string memory _name, string memory _symbol) ERC4626(_token, _name, _symbol) {
        // set up token behaviour
        // set it up good
        asset = _token;
    }
    
    


    function depositToVault(
        ERC4626 vault,
        address to,
        uint256 amount,
        uint256 minSharesOut
    ) external payable returns (uint256 sharesOut) {
        // pullToken(ERC20(vault.asset()), amount, address(this));
        // return deposit(vault, to, amount, minSharesOut);
    }

    function withdrawToDeposit(
        ERC4626 fromVault,
        ERC4626 toVault,
        address to,
        uint256 amount,
        uint256 maxSharesIn,
        uint256 minSharesOut
    ) external payable returns (uint256 sharesOut) {
        // withdraw(fromVault, address(this), amount, maxSharesIn);
        // return deposit(toVault, to, amount, minSharesOut);
    }

    function redeemToDeposit(
        ERC4626 fromVault,
        ERC4626 toVault,
        address to,
        uint256 shares,
        uint256 minSharesOut
    ) external payable returns (uint256 sharesOut) {
        // amount out passes through so only one slippage check is needed
        // uint256 amount = redeem(fromVault, address(this), shares, 0);
        // return deposit(toVault, to, amount, minSharesOut);
    }

    function depositMax(
        ERC4626 vault,
        address to,
        uint256 minSharesOut
    ) public payable returns (uint256 sharesOut) {
        // ERC20 asset = ERC20(vault.asset());
        // uint256 assetBalance = asset.balanceOf(msg.sender);
        uint256 maxDeposit = vault.maxDeposit(to);
        uint256 amount = maxDeposit < assetBalance ? maxDeposit : assetBalance;
        // pullToken(asset, amount, address(this));
        // return deposit(vault, to, amount, minSharesOut);
    }

    function redeemMax(
        ERC4626 vault,
        address to,
        uint256 minAmountOut
    ) public payable returns (uint256 amountOut) {
        uint256 shareBalance = vault.balanceOf(msg.sender);
        // uint256 maxRedeem = vault.maxRedeem(msg.sender);
        // uint256 amountShares = maxRedeem < shareBalance ? maxRedeem : shareBalance;
        // return redeem(vault, to, amountShares, minAmountOut);
    }

    /*///////////////////////////////////////////////////////////////
                        INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Example usage of hook. Pull funds from strategy to Vault if needed.
    /// Withdraw at least requested amount to the Vault. Covers withdraw/performance fees of strat. Leaves dust tokens.
    function beforeWithdraw(uint256 amount) internal {
        uint256 _withdraw = (amount + ((amount * 50) / 10000));
        // IController(controller).withdraw(address(asset), _withdraw);
    }


    /*///////////////////////////////////////////////////////////////
                        ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Sum of idle funds and funds deployed to Strategy.
    function totalAssets() public view override returns (uint256) {
        // return idleFloat() + IController(controller).balanceOf(address(asset));
        return assetBalance;
    }

    function assetsOf(address user) public view returns (uint256) {
        return previewRedeem(balanceOf[user]);
    }

    function assetsPerShare() public view returns (uint256) {
        return previewRedeem(10**decimals);
    }

    /// @notice Idle funds in Vault, i.e deposits before earn()
    function idleFloat() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }


    function maxWithdraw(address user) public view override returns (uint256) {
        return assetsOf(user);
    }

    function maxRedeem(address user) public view override returns (uint256) {
        return balanceOf[user];
    }


    /// @notice Transfer any available and not limited by cap funds to Controller (=>Strategy).
    function earn() public {

    }

    function harvest(address reserve, uint256 amount) external {
        // require(msg.sender == controller, "!controller");
        require(reserve != address(asset), "token");
        // IERC20(reserve).transfer(controller, amount);
    }

    function depositAll() external {
        deposit(asset.balanceOf(msg.sender), msg.sender);
    }

    function withdrawAll() external {
        withdraw(assetsOf(msg.sender), msg.sender, msg.sender);
    }
}
