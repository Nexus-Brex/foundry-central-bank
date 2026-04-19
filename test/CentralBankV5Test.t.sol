//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//import Foundry test tools
import {Test} from "forge-std/Test.sol";

//import contract
import {IlaCoin} from "../src/IlaCoin.sol";
import {CentralBankV5_Yield} from "../src/CentralBankV5_Yield.sol";

contract CentralBankV5Test is Test {
    //State Variables
    IlaCoin ilaCoin;
    CentralBankV5_Yield bank;

    //tests address - makeAddr creates deterministic addresses with a readeble name
    address owner = makeAddr("owner");
    address user = makeAddr("user");

    //costant for tests
    uint256 constant INITIAL_SUPPLY = 1_000_000 ether;
    uint256 constant FUND_AMOUNT = 500 ether;
    uint256 constant STAKE_AMOUNT = 20 ether;
    uint256 constant SECONDS_PER_MONTH = 2_592_000;

    //setUp() run before every test
    //like the manual deploy
    function setUp() public {
        //vm.prank -> next transaction run like owner
        vm.startPrank(owner);

        //deploy IlaCoin - owner receive 1000000 ILA
        ilaCoin = new IlaCoin(INITIAL_SUPPLY);

        //deploy Bank - same token for reward and staking
        bank = new CentralBankV5_Yield(address(ilaCoin), address(ilaCoin));

        //owner give fund at bank with 500ILA
        ilaCoin.approve(address(bank), FUND_AMOUNT);
        bank.fundRewards(FUND_AMOUNT);

        //owner transfer 20ILA to user for staking
        ilaCoin.transfer(user, STAKE_AMOUNT);

        vm.stopPrank();
    }

    //TEST 1 - verify the deploy status
    function testInitialSetup() public view {
        //bank must have 500ILA
        assertEq(ilaCoin.balanceOf(address(bank)), FUND_AMOUNT);
        //user must have 20ILA
        assertEq(ilaCoin.balanceOf(address(user)), STAKE_AMOUNT);
        //the owner of the contract need to be a "owner"
        assertEq(bank.owner(), owner);
    }

    //TEST 2 - verify the stake works
    function testStake() public {
        //vm.startPrank -> all the follow are the user's actions
        vm.startPrank(user);

        ilaCoin.approve(address(bank), STAKE_AMOUNT);
        bank.stake(STAKE_AMOUNT);

        vm.stopPrank();

        //read the database of bank for user
        (uint256 stakedBalance, , ) = bank.databaseBank(user);

        //stakedBalance must be 20ILA
        assertEq(stakedBalance, STAKE_AMOUNT);
    }

    // TEST 3 - verify that after 1 month rewards are 3% of 20ILA
    function testRewardAfterOneMonth() public {
        vm.startPrank(user);
        ilaCoin.approve(address(bank), STAKE_AMOUNT);
        bank.stake(STAKE_AMOUNT);
        vm.stopPrank();

        //vm.warp -> let's move time forward a month
        vm.warp(block.timestamp + SECONDS_PER_MONTH);

        uint256 reward = bank.calculateReward(user);

        //the reward must be 0.6 ILA
        //we use assertApproxEqRel: accept 1% difference
        assertApproxEqRel(reward, 0.6 ether, 1e16);
    }

    //TEST 4 - only owner can call fundRewards
    function testOnlyOwnerCanFund() public {
        vm.startPrank(user);
        vm.expectRevert("Not the owner!");
        bank.fundRewards(100 ether);
        vm.stopPrank();
    }

    //TEST 5 - Cannot stake 0 token
    function testCannotStakeZero() public {
        vm.startPrank(user);
        ilaCoin.approve(address(bank), STAKE_AMOUNT);
        vm.expectRevert("Cannot stake 0!");
        bank.stake(0);
        vm.stopPrank();
    }
}
