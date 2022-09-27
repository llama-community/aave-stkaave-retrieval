// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

// testing libraries
import "@forge-std/Test.sol";

// contract dependencies
import "../external/aave/IStaticATokenLM.sol";
import "../external/aave/IAaveIncentivesController.sol";
import {IAaveGovernanceV2} from "../external/aave/IAaveGovernanceV2.sol";
import {StkAaveRetrieval} from "../StkAaveRetrieval.sol";
import {ProposalPayload} from "../ProposalPayload.sol";
import {DeployMainnetProposal} from "../../script/DeployMainnetProposal.s.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";

contract StkAaveRetrievalE2ETest is Test {
    IAaveGovernanceV2 private aaveGovernanceV2 = IAaveGovernanceV2(0xEC568fffba86c094cf06b22134B23074DFE2252c);

    address[] private aaveWhales;

    address private proposalPayloadAddress;

    uint256 private proposalId;

    StkAaveRetrieval private stkAaveRetrieval;
    ProposalPayload private proposalPayload;

    IERC20 STK_AAVE = IERC20(0x4da27a545c0c5B758a6BA100e3a049001de870f5);

    address incentivesControllerAddr;
    address balancerDAO; 
    address balancerMultisig;

    IStaticATokenLM wrapped_aDAI;
    IStaticATokenLM wrapped_aUSDC;
    IStaticATokenLM wrapped_aUSDT;

    function setUp() public {
        // To fork at a specific block: vm.createSelectFork(vm.rpcUrl("mainnet", BLOCK_NUMBER));
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        // aave whales may need to be updated based on the block being used
        // these are sometimes exchange accounts or whale who move their funds

        // select large holders here: https://etherscan.io/token/0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9#balances
        aaveWhales.push(0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8);
        aaveWhales.push(0x26a78D5b6d7a7acEEDD1e6eE3229b372A624d8b7);
        aaveWhales.push(0x2FAF487A4414Fe77e2327F0bf4AE2a264a776AD2);

        stkAaveRetrieval = new StkAaveRetrieval();
        incentivesControllerAddr = stkAaveRetrieval.INCENTIVES_CONTROLLER();
        balancerDAO = stkAaveRetrieval.BALANCER_DAO();
        balancerMultisig = stkAaveRetrieval.BALANCER_MULTISIG();
        wrapped_aDAI = IStaticATokenLM(stkAaveRetrieval.WRAPPED_ADAI());
        wrapped_aUSDC = IStaticATokenLM(stkAaveRetrieval.WRAPPED_AUSDC());
        wrapped_aUSDT = IStaticATokenLM(stkAaveRetrieval.WRAPPED_AUSDT());


        // create proposal is configured to deploy a Payload contract and call execute() as a delegatecall
        _createProposal(stkAaveRetrieval);

        // these are generic steps for all proposals - no updates required
        _voteOnProposal();
        _skipVotingPeriod();
        _queueProposal();
        _skipQueuePeriod();
    }

    function testSetup() public {
        IAaveGovernanceV2.ProposalWithoutVotes memory proposal = aaveGovernanceV2.getProposalById(proposalId);
        assertEq(proposalPayloadAddress, proposal.targets[0], "TARGET_IS_NOT_PAYLOAD");

        IAaveGovernanceV2.ProposalState state = aaveGovernanceV2.getProposalState(proposalId);
        assertEq(uint256(state), uint256(IAaveGovernanceV2.ProposalState.Queued), "PROPOSAL_NOT_IN_EXPECTED_STATE");
    }

    function testClaimerUnsetPreProposal() public {    
        // Call retrieve() on StkAaveRetrieval contract as Balancer multisig without the Proposal being executed
        vm.prank(balancerMultisig);
        vm.expectRevert(bytes("Contract not set as claimer"));
        stkAaveRetrieval.retrieve();
        
    }

    function testRetrieveNotBalancerMultisigPreProposal() public {
        // Call retrieve() on StkAaveRetrieval contract without the Proposal being executed
        // the msg.sender will be this contract, which is NOT the balancer multisig
        _executeProposal();
        vm.expectRevert(bytes("Only Balancer Multisig"));
        stkAaveRetrieval.retrieve();
    }

    function testExecute() public {
        // check that originally claimer is unset, then is correctly set to retrieval contract
        IAaveIncentivesController incentivesController = IAaveIncentivesController(incentivesControllerAddr);
        assertEq(incentivesController.getClaimer(balancerDAO), address(0), "CLAIMER_NOT_ZERO");
        _executeProposal();
        assertEq(incentivesController.getClaimer(balancerDAO), address(stkAaveRetrieval), "CLAIMER_NOT_RETRIEVAL_CONTRACT");
    }

    function testRetrievePostProposal() public {
        _executeProposal();

        // check stkAaveBalance of balancermultisig is zero 
        assertEq(STK_AAVE.balanceOf(balancerMultisig), 0, "BALANCER_MULTISIG_STK_AAVE_BALANCE_NOT_ZERO");
        
        // check initial aToken reward balances of Balancer DAO
        uint256 expected_balance_ADAI = 507223394753535214703;
        uint256 expected_balance_AUSDC = 601800814685127542984;
        uint256 expected_balance_AUSDT = 390825845735555687901;
        assertEq(wrapped_aDAI.getUnclaimedRewards(balancerDAO), expected_balance_ADAI, "INCORRECT_WRAPPED_ADAI_REWARDS_INITIAL_BALANCE");
        assertEq(wrapped_aUSDC.getUnclaimedRewards(balancerDAO), expected_balance_AUSDC, "INCORRECT_WRAPPED_AUSDC_REWARDS_INITIAL_BALANCE");
        assertEq(wrapped_aUSDT.getUnclaimedRewards(balancerDAO), expected_balance_AUSDT, "INCORRECT_WRAPPED_AUSDT_REWARDS_INITIAL_BALANCE");

        // Mock as Balancer Multisig and call retrieve() on StkAaveRetrieval contract
        vm.prank(balancerMultisig);
        stkAaveRetrieval.retrieve();
        
        // check that stkAave balance is correct now 
        uint256 balancerDAOStkAAVEBalance = STK_AAVE.balanceOf(balancerMultisig);
        uint256 expectedStkAaveBalance = 1499850055174218445588;
        assertEq(balancerDAOStkAAVEBalance, expectedStkAaveBalance, "BALANCER_MULTISIG_STK_AAVE_BALANCE_NOT_ZERO");

        // check final aToken reward balances of Balancer DAO - all should be zero
        assertEq(wrapped_aDAI.getUnclaimedRewards(balancerDAO), 0, "INCORRECT_WRAPPED_ADAI_REWARDS_FINAL_BALANCE");
        assertEq(wrapped_aUSDC.getUnclaimedRewards(balancerDAO), 0, "INCORRECT_WRAPPED_AUSDC_REWARDS_FINAL_BALANCE");
        assertEq(wrapped_aUSDT.getUnclaimedRewards(balancerDAO), 0, "INCORRECT_WRAPPED_AUSDT_REWARDS_FINAL_BALANCE");
    }


    function _executeProposal() public {
        // execute proposal
        aaveGovernanceV2.execute(proposalId);

        // confirm state after
        IAaveGovernanceV2.ProposalState state = aaveGovernanceV2.getProposalState(proposalId);
        assertEq(uint256(state), uint256(IAaveGovernanceV2.ProposalState.Executed), "PROPOSAL_NOT_IN_EXPECTED_STATE");
    }

    /*******************************************************************************/
    /******************     Aave Gov Process - Create Proposal     *****************/
    /*******************************************************************************/

    function _createProposal(StkAaveRetrieval _stkAaveRetrieval) public {
        proposalPayload = new ProposalPayload(_stkAaveRetrieval);
        proposalPayloadAddress = address(proposalPayload);

        vm.prank(aaveWhales[0]);
        proposalId = DeployMainnetProposal._deployMainnetProposal(
            proposalPayloadAddress,
            0x344d3181f08b3186228b93bac0005a3a961238164b8b06cbb5f0428a9180b8a7 // TODO: Replace with actual IPFS Hash
        );
    }

    /*******************************************************************************/
    /***************     Aave Gov Process - No Updates Required      ***************/
    /*******************************************************************************/

    function _voteOnProposal() public {
        IAaveGovernanceV2.ProposalWithoutVotes memory proposal = aaveGovernanceV2.getProposalById(proposalId);
        vm.roll(proposal.startBlock + 1);
        for (uint256 i; i < aaveWhales.length; i++) {
            vm.prank(aaveWhales[i]);
            aaveGovernanceV2.submitVote(proposalId, true);
        }
    }

    function _skipVotingPeriod() public {
        IAaveGovernanceV2.ProposalWithoutVotes memory proposal = aaveGovernanceV2.getProposalById(proposalId);
        vm.roll(proposal.endBlock + 1);
    }

    function _queueProposal() public {
        aaveGovernanceV2.queue(proposalId);
    }

    function _skipQueuePeriod() public {
        IAaveGovernanceV2.ProposalWithoutVotes memory proposal = aaveGovernanceV2.getProposalById(proposalId);
        vm.warp(proposal.executionTime + 1);
    }
}
