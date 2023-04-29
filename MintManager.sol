// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "SignatureProcessor.sol";

contract MintManager is Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    mapping(address => SecretStorage) internal secrets;

    struct SecretStorage { 
        string secret;
        uint256 secretNum;
        }

    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    function mintERC20(address token,
        uint256 value, 
        bytes memory _signature, 
        uint256 _secretNum) external virtual nonReentrant() {
        require(secrets[token].secretNum > 0, "Secret not setuped");
        require(_secretNum >= secrets[token].secretNum, "Invalid secret number");
        (bool ok, uint256 newSecret) = SignatureProcessor._isSigned(_signature, keccak256(abi.encodePacked(secrets[token].secret,_secretNum)), msg.sender, _secretNum);
        require(ok, "Not allowed");
        secrets[token].secretNum = newSecret;
        (bool success, ) = token.call(abi.encodeWithSignature("mint(address,uint256)", msg.sender, value));
        require(success, "Error of mint");
    }

    function mintERC721(address token,
        bytes memory _signature, 
        uint256 _secretNum) external virtual nonReentrant() {
        require(secrets[token].secretNum > 0, "Secret not setuped");
        require(_secretNum >= secrets[token].secretNum, "Invalid secret number");
        (bool ok, uint256 newSecret) = SignatureProcessor._isSigned(_signature, keccak256(abi.encodePacked(secrets[token].secret,_secretNum)), msg.sender, _secretNum);
        require(ok, "Not allowed");
        secrets[token].secretNum = newSecret;
        (bool success, ) = token.call(abi.encodeWithSignature("safeMint(address)", msg.sender));
        require(success, "Error of mint");
    }

    function mintWithTokenIdERC721(address token,
        uint256 tokenId, 
        bytes memory _signature, 
        uint256 _secretNum) external virtual nonReentrant() {
        require(secrets[token].secretNum > 0, "Secret not setuped");
        require(_secretNum >= secrets[token].secretNum, "Invalid secret number");
        (bool ok, uint256 newSecret) = SignatureProcessor._isSigned(_signature, keccak256(abi.encodePacked(secrets[token].secret,_secretNum)), msg.sender, _secretNum);
        require(ok, "Not allowed");
        secrets[token].secretNum = newSecret;
        (bool success, ) = token.call(abi.encodeWithSignature("safeMintWithTokenId(address,uint256)", msg.sender, tokenId));
        require(success, "Error of mint");
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    function renounceOwnership() public virtual override onlyOwner {
        revert("Renounce Ownership forbidden");
    }

    function changeSecret(address _tokenAddr, address _location) public virtual onlyOwner {
        (string memory secret, uint256 secretNum) = SignatureProcessor._getSecret(_location);
        secrets[_tokenAddr] = SecretStorage(secret, secretNum);
    }
}