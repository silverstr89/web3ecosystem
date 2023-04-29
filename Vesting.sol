// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/**
 * @title VestingWallet
 * @dev This contract handles the vesting of Eth and ERC20 tokens for a given beneficiary. Custody of multiple tokens
 * can be given to this contract, which will release the token to the beneficiary following a given vesting schedule.
 * The vesting schedule is customizable through the {vestedAmount} function.
 *
 * Any token transferred to this contract will follow the vesting schedule as if they were locked from the beginning.
 * Consequently, if the vesting has already started, any amount of tokens sent to this contract will (at least partly)
 * be immediately releasable.
 */

 
contract VestingWallet is Context, Ownable {
    event EtherReleased(uint256 amount);
    event ERC20Released(address indexed token, uint256 amount);

    event RestartedVesting(uint64 newStartTimestamp, uint64 newDurationSeconds);

    uint256 private _released;
    mapping(address => uint256) private _erc20Released;
    address private _beneficiary;
    uint64 private _start;
    uint64 private _duration;

    /**
     * @dev Set the beneficiary, start timestamp and vesting duration of the vesting wallet.
     */
    constructor(address beneficiaryAddress, uint64 startTimestamp, uint64 durationSeconds) payable {
        require(beneficiaryAddress != address(0), "VestingWallet: beneficiary is zero address");
        _beneficiary = beneficiaryAddress;
        _start = startTimestamp;
        _duration = durationSeconds;
    }

    /**
     * @dev The contract should be able to receive Eth.
     */
    receive() external payable virtual {}

    function restartVesting(uint64 startTimestamp, uint64 durationSeconds, address token) public virtual onlyOwner {
        _start = startTimestamp;
        _duration = durationSeconds;
        _released = 0;
        delete _erc20Released[_beneficiary];
        emit RestartedVesting(startTimestamp, durationSeconds);
        emit EtherReleased(address(this).balance);
        emit ERC20Released(token, IERC20(token).balanceOf(address(this)));
        payable(_beneficiary).transfer(address(this).balance);
        SafeERC20.safeTransfer(IERC20(token), _beneficiary, IERC20(token).balanceOf(address(this)));
    }

    /**
     * @dev Getter for the beneficiary address.
     */
    function beneficiary() public view virtual returns (address) {
        return _beneficiary;
    }

    /**
     * @dev Getter for the start timestamp.
     */
    function start() public view virtual returns (uint256) {
        return _start;
    }

    /**
     * @dev Getter for the vesting duration.
     */
    function duration() public view virtual returns (uint256) {
        return _duration;
    }

    /**
     * @dev Amount of eth already released
     */
    function released() public view virtual returns (uint256) {
        return _released;
    }

    /**
     * @dev Amount of token already released
     */
    function released(address token) public view virtual returns (uint256) {
        return _erc20Released[token];
    }

    /**
     * @dev Getter for the amount of releasable eth.
     */
    function releasable() public view virtual returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released();
    }

    /**
     * @dev Getter for the amount of releasable `token` tokens. `token` should be the address of an
     * IERC20 contract.
     */
    function releasable(address token) public view virtual returns (uint256) {
        return vestedAmount(token, uint64(block.timestamp)) - released(token);
    }

    /**
     * @dev Release the native token (ether) that have already vested.
     *
     * Emits a {EtherReleased} event.
     */
    function release() public virtual onlyOwner {
        uint256 amount = releasable();
        _released += amount;
        emit EtherReleased(amount);
        Address.sendValue(payable(beneficiary()), amount);
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {ERC20Released} event.
     */
    function release(address token) public virtual onlyOwner {
        uint256 amount = releasable(token);
        _erc20Released[token] += amount;
        emit ERC20Released(token, amount);
        SafeERC20.safeTransfer(IERC20(token), beneficiary(), amount);
    }

    /**
     * @dev Calculates the amount of ether that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(uint64 timestamp) public view virtual returns (uint256) {
        return _vestingSchedule(address(this).balance + released(), timestamp);
    }

    /**
     * @dev Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(address token, uint64 timestamp) public view virtual returns (uint256) {
        return _vestingSchedule(IERC20(token).balanceOf(address(this)) + released(token), timestamp);
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
     * an asset given its total historical allocation.
     */
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view virtual returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp > start() + duration()) {
            return totalAllocation;
        } else {
            return (totalAllocation * (timestamp - start())) / duration();
        }
    }

    function transferOwnership(address newOwner) public virtual override onlyOwner {
        require(newOwner != address(0));
        revert("Transfer Ownership forbidden");
    }

    function renounceOwnership() public virtual override onlyOwner {
        revert("Renounce Ownership forbidden");
    }

    function destroy(address token) public onlyOwner {
        SafeERC20.safeTransfer(IERC20(token), msg.sender, IERC20(token).balanceOf(address(this)));
        selfdestruct(payable(msg.sender));
    }
}


contract CustomVestingWallet is Ownable {
    IERC20 public parentToken;
    mapping(address => VestingWallet) public walletMap;
    address[] private beneficiaryAddresses;
    event CreatedVesting(address indexed wallet, address indexed beneficiary, uint64 start, uint64 duration, uint256 tokenValue);
    event DeleteVesting(address indexed wallet, address indexed beneficiary);

    constructor(address _parentToken) {
        require(IERC20(_parentToken).totalSupply() != 0, "Wrong ERC20");
        parentToken = IERC20(_parentToken);
    }

    receive() external payable virtual {}

    function createVesting(address _beneficiary, uint64 _start, uint64 _durationDays, uint256 _tokenValue) public onlyOwner {
        if (address(walletMap[_beneficiary]) != address(0)) {
            _newPeriodVesting(_beneficiary, _start, _durationDays, _tokenValue);
        }
        require(parentToken.balanceOf(address(this))>=_tokenValue, "Not enough tokens for transfer");
        walletMap[_beneficiary] = new VestingWallet(_beneficiary, _start, _durationDays *24*60*60);
        beneficiaryAddresses.push(_beneficiary);
        SafeERC20.safeTransfer(parentToken, address(walletMap[_beneficiary]), _tokenValue);
        emit CreatedVesting(address(walletMap[_beneficiary]),_beneficiary, _start, _durationDays *24*60*60, _tokenValue);
    }

    function _newPeriodVesting(address _beneficiary, uint64 _start, uint64 _durationDays, uint256 _newTokenValue) internal onlyOwner  {
        require(address(walletMap[_beneficiary]) != address(0), "Vesting Wallet doesn't exist");
        require(parentToken.balanceOf(address(this))>=_newTokenValue, "Not enough tokens for transfer");
        walletMap[_beneficiary].restartVesting(_start, _durationDays *24*60*60, address(parentToken));
        SafeERC20.safeTransfer(parentToken, address(walletMap[_beneficiary]), _newTokenValue);
    }

    function deleteBeneficiary(address _beneficiary) public onlyOwner {
        require(address(walletMap[_beneficiary]) != address(0), "Vesting Wallet doesn't exist");
        walletMap[_beneficiary].destroy(address(parentToken));
        emit DeleteVesting(address(walletMap[_beneficiary]),_beneficiary);
        delete walletMap[_beneficiary];
        remove(_beneficiary);
    }

        /**
     * @dev Getter for the beneficiary address.
     */
    function beneficiary(address _beneficiary) public view virtual returns (address) {
        require(address(walletMap[_beneficiary]) != address(0), "Vesting Wallet doesn't exist");
        return walletMap[_beneficiary].beneficiary();
    }

    /**
     * @dev Getter for the start timestamp.
     */
    function start(address _beneficiary) public view virtual returns (uint256) {
        require(address(walletMap[_beneficiary]) != address(0), "Vesting Wallet doesn't exist");
        return walletMap[_beneficiary].start();
    }

    /**
     * @dev Getter for the vesting duration.
     */
    function duration(address _beneficiary) public view virtual returns (uint256) {
        require(address(walletMap[_beneficiary]) != address(0), "Vesting Wallet doesn't exist");
        return walletMap[_beneficiary].duration();
    }

    /**
     * @dev Amount of token already released
     */
    function released(address _beneficiary) public view virtual returns (uint256) {
        require(address(walletMap[_beneficiary]) != address(0), "Vesting Wallet doesn't exist");
        return walletMap[_beneficiary].released(address(parentToken));
    }

    /**
     * @dev Getter for the amount of releasable `token` tokens. `token` should be the address of an
     * IERC20 contract.
     */
    function releasable(address _beneficiary) public view virtual returns (uint256) {
        require(address(walletMap[_beneficiary]) != address(0), "Vesting Wallet doesn't exist");
        return walletMap[_beneficiary].releasable(address(parentToken));
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {ERC20Released} event.
     */
    function release(address _beneficiary) public virtual {
        require(address(walletMap[_beneficiary]) != address(0), "Vesting Wallet doesn't exist");
        require(msg.sender == owner() || msg.sender == _beneficiary, "Must be owner or beneficiary");
        return walletMap[_beneficiary].release(address(parentToken));
    }

    /**
     * @dev Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(address _beneficiary, uint64 timestamp) public view virtual returns (uint256) {
        require(address(walletMap[_beneficiary]) != address(0), "Vesting Wallet doesn't exist");
        return walletMap[_beneficiary].vestedAmount(address(parentToken), timestamp);
    }

    function beneficiaryList() public view returns(address[] memory) {
        return beneficiaryAddresses;
    }

    function remove(address _valueToFindAndRemove) internal virtual onlyOwner {
        for (uint i = 0; i < beneficiaryAddresses.length; i++){
            if(beneficiaryAddresses[i] == _valueToFindAndRemove){
                beneficiaryAddresses[i] = address(0);
                return;
            }
        }
    }

    function withdrawToOwner() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
        SafeERC20.safeTransfer(parentToken, msg.sender, parentToken.balanceOf(address(this)));
    }

    function withdrawToOwnerCustomToken(address token) public onlyOwner {
        require(address(parentToken) != token, "This is parent token");
        SafeERC20.safeTransfer(IERC20(token), msg.sender, IERC20(token).balanceOf(address(this)));
    }

    function renounceOwnership() public virtual override onlyOwner {
        revert("Renounce Ownership forbidden");
    }

}