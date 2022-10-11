// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "@forge-std/console.sol";
import {Script} from "@forge-std/Script.sol";
import {StkAaveRetrieval} from "../src/StkAaveRetrieval.sol";
import {ProposalPayload} from "../src/ProposalPayload.sol";

contract DeployContracts is Script {
    function run() external {
        vm.startBroadcast();
        StkAaveRetrieval stkAaveRetrieval = new StkAaveRetrieval();
        console.log("StkAaveRetrieval address", address(stkAaveRetrieval));
        ProposalPayload proposalPayload = new ProposalPayload(stkAaveRetrieval);
        console.log("Proposal Payload address", address(proposalPayload));
        vm.stopBroadcast();
    }
}
