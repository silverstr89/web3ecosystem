// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "SignatureProcessor.sol";


contract Locker is Initializable, ERC721HolderUpgradeable, ERC1155HolderUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    string internal secret;
    uint256 internal secretNum;

    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC721Holder_init();
        __ERC1155Holder_init();
        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    receive() external payable virtual {}

    function transferERC20(IERC20Upgradeable token,
        uint256 value, bytes memory _signature, uint256 _secretNum) external virtual nonReentrant() {
        if (msg.sender != owner()){
            secretNum = _signerCheck(_signature, _secretNum);
        }
        SafeERC20Upgradeable.safeTransfer(token, msg.sender, value);
    }

    function transferERC721(IERC721Upgradeable token,
        uint256 tokenId, bytes memory _signature, uint256 _secretNum) external virtual nonReentrant() {
        if (msg.sender != owner()){
            secretNum = _signerCheck(_signature, _secretNum);
        }
        token.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function transferERC1155(IERC1155Upgradeable token,
        uint256 id, uint256 amount, 
        bytes memory _signature, uint256 _secretNum) external virtual nonReentrant() {
        if (msg.sender != owner()){
            secretNum = _signerCheck(_signature, _secretNum);
        }
        token.safeTransferFrom(address(this), msg.sender, id, amount, msg.data);
    }

    function transferMatic(uint256 _value, bytes memory _signature, uint256 _secretNum) external virtual nonReentrant() {
        if (msg.sender != owner()){
            secretNum = _signerCheck(_signature, _secretNum);
        }
        AddressUpgradeable.sendValue(payable(msg.sender), _value);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    function renounceOwnership() public virtual override onlyOwner {
        revert("Renounce Ownership forbidden");
    }

    function _signerCheck(bytes memory _signature, uint256 _secretNum) internal virtual returns (uint256){
        bytes memory bytesSecret = bytes(secret);
        require(bytesSecret.length != 0, "Secret string must be setup");
        require(_secretNum >= secretNum, "Invalid secret number");
        (bool ok, uint256 newSecret) = SignatureProcessor._isSigned(_signature, keccak256(abi.encodePacked(secret,_secretNum)), msg.sender, _secretNum);
        require(ok, "Not allowed");
        return newSecret;
    }

    function changeSecret(address _location) public virtual onlyOwner {
        (secret, secretNum) = SignatureProcessor._getSecret(_location);
    }
}