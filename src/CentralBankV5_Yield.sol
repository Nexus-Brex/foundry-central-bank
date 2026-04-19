//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//interface (the translator)
interface IERC20 {
    //move the token from the contract to the client(for withdraw and rewards)
    function transfer(address to, uint256 amount) external returns (bool);

    //move the client's token to the contract(for stake() e fundReward()
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract CentralBankV5_Yield {
    //this is a Fixed-Rate DeFi Yield Staking protocol
    //users deposit ilaCoin ,wait eìand earn ILA
    //state variables are pemanently stored on blockchain and cost gas

    //token that user deposit for staking: ilaCoin
    //public = Foundry and anyone can read them without a dedicated function
    IERC20 public rewardToken;
    IERC20 public stakingToken;

    //fixed rate - for each second in stake, user earn
    uint256 public constant SECONDS_PER_MONTH = 2_592_000; // 30 days x 86400 seconds
    uint256 public rewardRate = 300; // 300 = 3.00% (in basis point:1 = 0.01%)
    uint256 public constant PRECISION = 1e18;
    address public owner;

    //structure of the client

    struct Staker {
        //how many ILA deposited
        uint256 stakedBalance;
        //client internal time
        uint256 lastUpdateTime;
        //the temporary safe for rewards
        uint256 accumulatedRewards;
    }

    //link the address ro the client
    mapping(address => Staker) public databaseBank;

    //constructor ( when we deploy, we assign real address to token)
    constructor(address _stakingToken, address _rewardToken) {
        //who deploy will be owner
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    //the modifier for onlyOwner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner!");
        _;
    }

    //the modifier (key of DeFi)
    //instaed to rewriting the reward recalculation in each function
    //we use the modifier before user deposits or withdraws
    //this modifier pauses the action, update reward count up the
    //precise second and then continues it
    modifier updateReward(address _account) {
        //calculate how many rewards you have from your last update
        uint256 earned = calculateReward(_account);

        //save the reward in the internal safe
        databaseBank[_account].accumulatedRewards += earned;
        //reset the time IMPORTANT
        databaseBank[_account].lastUpdateTime = block.timestamp;
        //go to original funtion
        _;
    }

    //function fundRewards - we fund the bank
    function fundRewards(uint256 _amount) public onlyOwner {
        require(_amount > 0, "Amount must be greater than 0!");
        //move token from msg.sender to the contract
        bool success = rewardToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "Funding failed!");
    }

    //function deposit
    function stake(uint256 _amount) public updateReward(msg.sender) {
        require(_amount > 0, "Cannot stake 0!");
        //effect - update the balance
        databaseBank[msg.sender].stakedBalance += _amount;
        //interaction- move the usdc from his wallet to our contract
        bool success = stakingToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "Error: Deposit failed!");
    }

    //function withdraw
    function withdraw(uint256 _amount) public updateReward(msg.sender) {
        require(_amount > 0, " Cannot withdraw 0!!");
        require(databaseBank[msg.sender].stakedBalance >= _amount, " You haven't enought funds!");
        //effect ,update the balance
        databaseBank[msg.sender].stakedBalance -= _amount;
        //interaction, move token to the user
        bool success = stakingToken.transfer(msg.sender, _amount);
        require(success, "Withdraw failed!");
    }

    //function claim
    function claimRewards() public updateReward(msg.sender) {
        //rewardToClaim = 5_000_000_000_000_000_000 /1e18 = 5 token
        uint256 rewardToClaim = databaseBank[msg.sender].accumulatedRewards;

        require(rewardToClaim > 0, "No rewards to claim!");
        //verify if the bank have enought funds
        require(rewardToken.balanceOf(address(this)) >= rewardToClaim, "Bank is out of funds!");
        //effect
        databaseBank[msg.sender].accumulatedRewards = 0;
        //interaction
        bool success = rewardToken.transfer(msg.sender, rewardToClaim);
        require(success, "Reward transfer failed!");
    }

    //function calculatedReward(view) - no gas
    function calculateReward(address _account) public view returns (uint256) {
        //"memory" --> temporary memory not saved on blockchain
        Staker memory currentUser = databaseBank[_account];
        //if the user haven't funds in stake, rewards are 0
        if (currentUser.stakedBalance == 0) {
            return 0;
        }

        //calculate time from last action
        uint256 timeElapsed = block.timestamp - currentUser.lastUpdateTime;

        //reward scaled = (balance*seconds*rate*PRECISION)/100_000
        uint256 currentReward = (currentUser.stakedBalance * timeElapsed * rewardRate) / (SECONDS_PER_MONTH * 10_000);

        return currentReward;
    }
}
