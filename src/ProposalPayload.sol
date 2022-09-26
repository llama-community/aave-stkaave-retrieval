// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./external/aave/IAaveIncentivesController.sol";
import {StkAaveRetrieval} from "./StkAaveRetrieval.sol";

/**
 * @title Proposal Payload to be executed by AAVE Governance
 * @author Dan Hepworth (djh58)
 * @notice This payload sets the StkAaveRetrieval contract as the claimer on behalf of 0xBA12222222228d8Ba445958a75a0704d566BF2C8
 * Governance Forum Post: https://governance.aave.com/t/arc-whitelist-balancer-s-liquidity-mining-claim/9724
 * Snapshot: TBD
 */
contract ProposalPayload {
    /// @dev this is the address we're claiming on behalf of
    address public constant BALANCER_DAO = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    /// @dev this is the address of the Aave Incentives Controller, which manages and stores the claimers
    address public constant INCENTIVE_CONTROLLER = 0xd784927Ff2f95ba542BfC824c8a8a98F3495f6b5;

    StkAaveRetrieval public immutable stkAaveRetrieval;

    constructor(StkAaveRetrieval _stkAaveRetrieval) {
        stkAaveRetrieval = _stkAaveRetrieval;
    }

    /// @notice The AAVE governance executor calls this function to implement the proposal.
    function execute() external {
        IAaveIncentivesController(INCENTIVE_CONTROLLER).setClaimer(BALANCER_DAO, address(stkAaveRetrieval));
    }
}
