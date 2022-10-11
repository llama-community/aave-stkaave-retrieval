// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

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

    StkAaveRetrieval private stkAaveRetrieval;

    IERC20 public constant STK_AAVE = IERC20(0x4da27a545c0c5B758a6BA100e3a049001de870f5);

    address public incentivesControllerAddr;
    address public balancerDAO;
    address public balancerMultisig;

    IStaticATokenLM public wrappedADAI;
    IStaticATokenLM public wrappedAUSDC;
    IStaticATokenLM public wrappedAUSDT;

    function setUp() public {
        // To fork at a specific block: vm.createSelectFork(vm.rpcUrl("mainnet", BLOCK_NUMBER));
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        stkAaveRetrieval = new StkAaveRetrieval();
        incentivesControllerAddr = stkAaveRetrieval.INCENTIVES_CONTROLLER();
        balancerDAO = stkAaveRetrieval.BALANCER_DAO();
        balancerMultisig = stkAaveRetrieval.BALANCER_MULTISIG();
        wrappedADAI = IStaticATokenLM(stkAaveRetrieval.WRAPPED_ADAI());
        wrappedAUSDC = IStaticATokenLM(stkAaveRetrieval.WRAPPED_AUSDC());
        wrappedAUSDT = IStaticATokenLM(stkAaveRetrieval.WRAPPED_AUSDT());

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
        vm.expectRevert(bytes("Only Balancer Multisig"));
        stkAaveRetrieval.retrieve();
    }

    function testRetrieveNotBalancerMultisigPostProposal() public {
        GovHelpers.passVoteAndExecute(vm, proposalId);
        // the msg.sender will be this contract not the multisig
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
        uint256 beforeBalanceADAI = wrappedADAI.getUnclaimedRewards(balancerDAO);
        uint256 beforeBalanceAUSDC = wrappedAUSDC.getUnclaimedRewards(balancerDAO);
        uint256 beforeBalanceAUSDT = wrappedAUSDT.getUnclaimedRewards(balancerDAO);
        uint256 expectedBeforeBalanceADAI = 507223394753535214703;
        uint256 expectedBeforeBalanceAUSDC = 601800814685127542984;
        uint256 expectedBeforeBalanceAUSDT = 390825845735555687901;
        assertEq(beforeBalanceADAI, expectedBeforeBalanceADAI, "INCORRECT_WRAPPED_ADAI_REWARDS_INITIAL_BALANCE");
        assertEq(beforeBalanceAUSDC, expectedBeforeBalanceAUSDC, "INCORRECT_WRAPPED_AUSDC_REWARDS_INITIAL_BALANCE");
        assertEq(beforeBalanceAUSDT, expectedBeforeBalanceAUSDT, "INCORRECT_WRAPPED_AUSDT_REWARDS_INITIAL_BALANCE");

        uint256 totalClaimableStkAAVEBalance = beforeBalanceADAI + beforeBalanceAUSDC + beforeBalanceAUSDT;
        uint256 expectedTotalClaimableStkAaveBalance = 1499850055174218445588;
        assertEq(
            totalClaimableStkAAVEBalance,
            expectedTotalClaimableStkAaveBalance,
            "INCORRECT_TOTAL_CLAIMABLE_STK_AAVE_BALANCE"
        );

        // Mock as Balancer Multisig and call retrieve() on StkAaveRetrieval contract
        vm.prank(balancerMultisig);
        stkAaveRetrieval.retrieve();

        // check that stkAave balance is correct now
        uint256 afterStkAAVEBalance = STK_AAVE.balanceOf(balancerMultisig);
        assertEq(
            afterStkAAVEBalance,
            expectedTotalClaimableStkAaveBalance,
            "BALANCER_MULTISIG_STK_AAVE_BALANCE_INCORRECT"
        );

        // check final aToken reward balances of Balancer DAO - all should be zero
        assertEq(wrappedADAI.getUnclaimedRewards(balancerDAO), 0, "INCORRECT_wrappedADAI_REWARDS_FINAL_BALANCE");
        assertEq(wrappedAUSDC.getUnclaimedRewards(balancerDAO), 0, "INCORRECT_wrappedAUSDC_REWARDS_FINAL_BALANCE");
        assertEq(wrappedAUSDT.getUnclaimedRewards(balancerDAO), 0, "INCORRECT_wrappedAUSDT_REWARDS_FINAL_BALANCE");
    }
}
