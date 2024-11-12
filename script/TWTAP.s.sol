// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {TWTAP} from "../src/TWTAP.sol";

contract TWTAPScript is Script {

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address erc20 = 0xe6c9Fb16687BB9EC14dE31e4C1A8B3F4B488A1A2;
        address owner = msg.sender;
        TWTAP twTAP = new TWTAP(payable(erc20), owner);

        vm.stopBroadcast();
    }
}
