// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SecretStorage {
    //setup values before deploy
    string private secret = "";
    uint256 private secretNum = 0;

    function getSecret() public view returns (string memory,uint256){
        return (secret, secretNum);
    }

    function destroy() public {
        selfdestruct(payable(address(msg.sender)));
    }
}