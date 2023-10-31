// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeveloperSplitter {
    address public dev1;
    address public dev2;
    address public dev3;

    constructor(address _dev1, address _dev2, address _dev3) {
        dev1 = _dev1;
        dev2 = _dev2;
        dev3 = _dev3;
    }

    receive() external payable {
        // Fallback function to receive Ether
    }

    function deposit() public payable {
        // Deposit function to add more Ether to the contract balance
    }

    function withdrawEther() public {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "Contract balance is empty");

        uint256 eachShare = contractBalance / 3;
        
        payable(dev1).transfer(eachShare);
        payable(dev2).transfer(eachShare);
        payable(dev3).transfer(eachShare);
    }

    function withdrawERC20(IERC20 token) public {
        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance > 0, "Contract balance is empty");

        uint256 eachShare = contractBalance / 3;

        require(token.transfer(dev1, eachShare), "Transfer to dev1 failed");
        require(token.transfer(dev2, eachShare), "Transfer to dev2 failed");
        require(token.transfer(dev3, eachShare), "Transfer to dev3 failed");
    }
}
