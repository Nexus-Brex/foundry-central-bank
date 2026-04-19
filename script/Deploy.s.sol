//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {IlaCoin} from "../src/IlaCoin.sol";
import {CentralBankV5_Yield} from "../src/CentralBankV5_Yield.sol";

contract DeployAll is Script {
    function run() external {
        vm.startBroadcast();

        //deploy IlaCoin and save the address
        IlaCoin ilaCoin = new IlaCoin(1_000_000 ether);

        //deploy the Bank give the IlaCoin's address - same token for staking and rewards
        new CentralBankV5_Yield(address(ilaCoin), address(ilaCoin));

        vm.stopBroadcast();
    }
}
