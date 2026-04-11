//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//import ERC20 contrat from OpenZeppelin
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract IlaCoin is ERC20 {
    //the constructor is executed once at deploy
    //it takes the initial supply of token to be created
    //initialSupply: how many tokens?
    constructor(uint256 initialSupply) ERC20("Ilario Coin", "ILA") {
        //ERC20 Ilario Coin,ILA --> full name and symbol
        //_mint is the function on OpenZeppelin that create new Token
        _mint(msg.sender, initialSupply);
    }
}
