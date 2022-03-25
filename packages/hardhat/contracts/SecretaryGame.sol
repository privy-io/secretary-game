// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.11;

/// @title SecretaryGame
/// @notice A spin on the Secretary Game
/// @author 
/// @dev 
contract SecretaryGame {

    /// ============ Types ============

    // Possible votes (and Hidden before votes are revealed)
    enum Choice {
        Hidden,
        A,
        B
    }

    // A cryptographic committment to a certain vote
    struct VoteCommit {
        bytes32 commitment;
        uint256 amount;
        Choice choice;
    }

    /// ============ Immutable storage ============

    uint256 public immutable maxNum = 999; // scores drawn go up to maxNum + 1 (sabotage can push higher)
    uint256 public immutable gameLength = 30; // 30 day games
    uint256 public immutable baseFee = 1e16; // fee lower bound
    uint256 public immutable poolFee = 100; // fraction of pool added to baseFee, here 1/100
    uint256 public immutable sabotagePremium = 3; // costs 3x as much to sabotage a player than claim a number
    uint256 public immutable sabotageEffectiveness = 10; // fraction of maxNum affected by sabotage

    uint256 public immutable _gameStart;

    /// ============ Mutable storage ============

    // Tracks your current number
    mapping(address => uint) public scores;
    mapping (uint => address) public players;
    uint _totalPlayers;

    // Stores total prize pool
    uint256 public prizePool = 0;

    /// ============ Events ============

    event Draw(address indexed player, uint256 fee, uint256 score);
    event Sabotage(address indexed saboteur, address indexed victim, uint256 fee, uint256 score);
    event Payout(address indexed winner, uint256 amount);

    constructor() {
        this._gameStart = this.timestamp;
        this._totalPlayers = 0;
    }

    /// ============ Functions ============

    /// @notice Returns winner, if first time pays founder's fee and sets prizePool
    function getWinner() private returns (address) {
        address winner;
        uint256 currentMax = 0;

        for(uint i = 0; i < this._totalPlayers ; i++) {
            if(scores[players[i]] > currentMax) {
                winner = players[i];
            }
        }
    }

    function isLiveGame() private view returns (bool) {
        return this.timestamp < this.gameStart + this.gameLength * 86400;
    }

    function getFee() private view returns (uint) {
        uint256 currentPool = address(this).balance;

        return this.baseFee + currentPool/this.poolFee;
    }

    function drawNumber() external payable {
        require(
            this.isLiveGame(),
            "Cannot draw number while game not live."
        );

        require(
            msg.value >= this.getFee(),
            "Must pay minimum fee to draw a number."
        );

    
        // TODO chainlink random number
        uint256 score = block.number % this.maxNum + 1;
        scores[msg.sender] = score;

        if (scores[msg.sender] <= 0) {
            this.players[this._totalPlayers] = msg.sender;
            this._totalPlayers += 1;
        }

        emit Draw(msg.sender, msg.value, score);
    }


    function sabotage(address victim) external payable {
        require(
            this.isLiveGame(),
            "Cannot sabotage while game is not live."
        );

        require(
            msg.value >= this.getFee() * sabotagePremium,
            "Must pay min fee * sabotage premium to sabotage a player"
        );

        require(
            scores[victim] > 0,
            "Victim must be a player"
        );

        // TODO random number
        uint256 rnd = block.number;

        uint isIncrease = rnd % 2;
        uint256 oldScore = scores[victim];
        uint256 newScore = oldScore;

        if (isIncrease) {
            newScore += this.maxNum / this.sabotageEffectiveness;            
        } else {
            newScore -= this.maxNum / this.sabotageEffectiveness;
        }
        scores[victim] = newScore;

        emit Sabotage(msg.sender, victim, msg.value, newScore);
    }

    function payout() external payable {
        require(
            isLiveGame(),
            "Cannot payout until game is over."
        );

        address winner = getWinner();
        require(
            msg.sender == winner,
            "Only winner can claim winnings."
        );

        uint256 winnings = address(this).balance;
        payable(msg.sender).transfer(winnings);

        emit Payout(msg.sender, winnings);
    }
}