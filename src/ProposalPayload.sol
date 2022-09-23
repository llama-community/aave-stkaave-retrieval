// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./external/aave/IStaticATokenLM.sol";
import "./external/aave/IAaveIncentivesController.sol";

/**
 * @title StkAaveRetrieval
 * @author Dan Hepworth (djh58) 
 * @notice This contract is used to claim stkAave rewards on behalf of the Balancer DAO contract and send those funds to their multisig
 * @notice Documentation: Documentation: https://docs.google.com/document/d/1Qbx6z1-rmatgQMNHhFm8kgpAWxzEHtpYzu_Z-MzLK7w/edit
 * Governance Forum Post: https://governance.aave.com/t/arc-whitelist-balancer-s-liquidity-mining-claim/9724 
 * Snapshot: TBD
 */
contract ProposalPayload {
    /// @dev this is recipient of the stkAave rewards
    address public constant BALANCER_MULTISIG = 0x10A19e7eE7d7F8a52822f6817de8ea18204F2e4f;
    
    /// @dev this is the address we're claiming on behalf of 
    address public constant BALANCER_DAO = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    
    /// @dev this is the address of the Aave Incentives Controller, which manages and stores the claimers
    address public constant INCENTIVE_CONTROLLER = 0xd784927Ff2f95ba542BfC824c8a8a98F3495f6b5;
    
    /// @dev these are the tokens which have accrued LM rewards
    address public constant WRAPPED_ADAI = 0x02d60b84491589974263d922D9cC7a3152618Ef6;
    address public constant WRAPPED_AUSDC = 0xd093fA4Fb80D09bB30817FDcd442d4d02eD3E5de;
    address public constant WRAPPED_AUSDT = 0xf8Fd466F12e236f4c96F7Cce6c79EAdB819abF58;
    address[] public WRAPPED_TOKENS = [WRAPPED_ADAI, WRAPPED_AUSDC, WRAPPED_AUSDT];

    /// @notice The AAVE governance executor calls this function to implement the proposal.
    function execute() external {
        require(IAaveIncentivesController(INCENTIVE_CONTROLLER).getClaimer(BALANCER_DAO) == address(this), "Contract not set as claimer");
        for (uint256 i = 0; i < WRAPPED_TOKENS.length; i++) {
            IStaticATokenLM(WRAPPED_TOKENS[i]).claimRewardsOnBehalf(BALANCER_DAO, BALANCER_MULTISIG, true);  
        }
    }
}
