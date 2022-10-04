// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

// testing libraries
import "@forge-std/Test.sol";

// contract dependencies
import "../external/aave/IStaticATokenLM.sol";
import "../external/aave/IAaveIncentivesController.sol";
import {GovHelpers} from "@aave-helpers/GovHelpers.sol";
import {AaveV2Ethereum} from "@aave-address-book/AaveV2Ethereum.sol";
import {StkAaveRetrieval} from "../StkAaveRetrieval.sol";
import {ProposalPayload} from "../ProposalPayload.sol";
import {DeployMainnetProposal} from "../../script/DeployMainnetProposal.s.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";

contract StkAaveRetrievalE2ETest is Test {
    address public constant AAVE_WHALE = 0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8;

    uint256 public proposalId;

    address[] private aaveWhales;

    address private proposalPayloadAddress;

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

        stkAaveRetrieval = new StkAaveRetrieval();
        incentivesControllerAddr = stkAaveRetrieval.INCENTIVES_CONTROLLER();
        balancerDAO = stkAaveRetrieval.BALANCER_DAO();
        balancerMultisig = stkAaveRetrieval.BALANCER_MULTISIG();
        wrapped_aDAI = IStaticATokenLM(stkAaveRetrieval.WRAPPED_ADAI());
        wrapped_aUSDC = IStaticATokenLM(stkAaveRetrieval.WRAPPED_AUSDC());
        wrapped_aUSDT = IStaticATokenLM(stkAaveRetrieval.WRAPPED_AUSDT());
        // Deploy Payload
        ProposalPayload proposalPayload = new ProposalPayload(stkAaveRetrieval);

        // Create Proposal
        vm.prank(AAVE_WHALE);
        proposalId = DeployMainnetProposal._deployMainnetProposal(
            address(proposalPayload),
            0x344d3181f08b3186228b93bac0005a3a961238164b8b06cbb5f0428a9180b8a7 // TODO: Replace with actual IPFS Hash
        );
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
        GovHelpers.passVoteAndExecute(vm, proposalId);
        vm.expectRevert(bytes("Only Balancer Multisig"));
        stkAaveRetrieval.retrieve();
    }

    function testExecute() public {
        // check that originally claimer is unset, then is correctly set to retrieval contract
        IAaveIncentivesController incentivesController = IAaveIncentivesController(incentivesControllerAddr);
        assertEq(incentivesController.getClaimer(balancerDAO), address(0), "CLAIMER_NOT_ZERO");
        // Pass vote and execute proposal
        GovHelpers.passVoteAndExecute(vm, proposalId);
        assertEq(
            incentivesController.getClaimer(balancerDAO),
            address(stkAaveRetrieval),
            "CLAIMER_NOT_RETRIEVAL_CONTRACT"
        );
    }

    function testRetrievePostProposal() public {
        GovHelpers.passVoteAndExecute(vm, proposalId);

        // check stkAaveBalance of balancermultisig is zero
        assertEq(STK_AAVE.balanceOf(balancerMultisig), 0, "BALANCER_MULTISIG_STK_AAVE_BALANCE_NOT_ZERO");

        // check initial aToken reward balances of Balancer DAO
        uint256 before_balance_ADAI = wrapped_aDAI.getUnclaimedRewards(balancerDAO);
        uint256 before_balance_AUSDC = wrapped_aUSDC.getUnclaimedRewards(balancerDAO);
        uint256 before_balance_AUSDT = wrapped_aUSDT.getUnclaimedRewards(balancerDAO);
        assertTrue(before_balance_ADAI > 0, "ZERO_WRAPPED_ADAI_REWARDS_INITIAL_BALANCE");
        assertTrue(before_balance_AUSDC > 0, "ZERO_WRAPPED_AUSDC_REWARDS_INITIAL_BALANCE");
        assertTrue(before_balance_AUSDT > 0, "ZERO_WRAPPED_AUSDT_REWARDS_INITIAL_BALANCE");

        uint256 beforeStkAAVEBalance = STK_AAVE.balanceOf(balancerMultisig);
        // Mock as Balancer Multisig and call retrieve() on StkAaveRetrieval contract
        vm.prank(balancerMultisig);
        stkAaveRetrieval.retrieve();

        // check that stkAave balance is correct now
        uint256 afterStkAAVEBalance = STK_AAVE.balanceOf(balancerMultisig);
        assertTrue(afterStkAAVEBalance > beforeStkAAVEBalance, "BALANCER_MULTISIG_STK_AAVE_BALANCE_UNCHANGED");

        // check final aToken reward balances of Balancer DAO - all should be zero
        assertEq(wrapped_aDAI.getUnclaimedRewards(balancerDAO), 0, "INCORRECT_WRAPPED_ADAI_REWARDS_FINAL_BALANCE");
        assertEq(wrapped_aUSDC.getUnclaimedRewards(balancerDAO), 0, "INCORRECT_WRAPPED_AUSDC_REWARDS_FINAL_BALANCE");
        assertEq(wrapped_aUSDT.getUnclaimedRewards(balancerDAO), 0, "INCORRECT_WRAPPED_AUSDT_REWARDS_FINAL_BALANCE");
    }
}
