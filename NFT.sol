// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract SpecialNFT is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, PausableUpgradeable, AccessControlUpgradeable, ERC721BurnableUpgradeable, UUPSUpgradeable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIdCounter;

    string private base;
    event ChangeBaseURI(string indexed baseURI);

    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC721_init("Special NFT Collection", "SNFT");
        __ERC721Enumerable_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC721Burnable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        //add manager address for minter role
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    function _baseURI() internal view override returns (string memory) {
        return base;
    }

    function baseURI() public view returns (string memory) {
        return _baseURI();
    }

    function changeBaseURI(string memory _base) external virtual onlyRole(MINTER_ROLE) {
        base = _base;
        emit ChangeBaseURI(base);
    }

    function pause() external virtual onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external virtual onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function safeMint(address to) external virtual onlyRole(MINTER_ROLE) {
        _safeMintInternal(to);
    }

    function _safeMintInternal(address to) internal virtual {
        uint256 tokenId = _tokenIdCounter.current();
        if (_exists(tokenId)) {
            tokenId = _getTokenId(tokenId);
            _tokenIdCounter._value = tokenId;
        }
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function safeMintWithTokenId(address to, uint256 tokenId) external virtual onlyRole(MINTER_ROLE) {
        _safeMint(to, tokenId);
    }

    function _getTokenId(uint256 _tokenId) internal virtual view returns (uint256) {
        uint256 tokenId = _tokenId;
        if (_exists(_tokenId)) {
            uint256 tId = tokenId+1;
            return _getTokenId(tId);
        } else {
            return tokenId;
        }
    }

    function safeMintBatch(address[] memory recipients, uint256[] memory amounts) external virtual onlyRole(MINTER_ROLE) {
        require(recipients.length == amounts.length, "Mismatch arrays");
        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            uint256 amount = amounts[i];
            for (uint256 j = 0; j < amount; j++) {
                _safeMintInternal(recipient);
            }
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function increment() internal {
        _tokenIdCounter.increment();
    }

    function current() internal view returns (uint256) {
        return _tokenIdCounter.current();
    }
}