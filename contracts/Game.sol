// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.11;

/// @title SecretaryGame
/// @notice A spin on the Secretary Game
/// @author
/// @dev

/// TODO think about multiple wallets
contract SecretaryGame {
    /// ============ Types ============

    /// ============ Immutable storage ============

    uint256 public immutable maxNum = 999; // scores drawn go up to maxNum + 1 (sabotage can push higher)
    uint256 public immutable gameLength = 30; // 30 day games
    uint256 public immutable fee = 1e18; // 1 ETH
    uint256 public immutable sabotagePremium = 3; // costs 3x as much to sabotage a player than claim a number
    uint256 public immutable sabotageEffectiveness = 10; // fraction of maxNum affected by sabotage
    uint256 public immutable sabotageFeePortion = 2;
    uint256 public immutable creatorFeePortion = 10;
    address public immutable creatorAddress =
        0x7963679e3D4Ad52e23Bff2e9Aed24337009e737b; // TODO CHANGE

    /// ============ Mutable storage ============

    uint256 _gameStart;

    // Tracks game state
    mapping(address => uint256) public scores;
    mapping(address => uint256) public earnings;
    address[] public players;
    uint256 private _totalPlayers;

    bool private gameClosed;

    // Stores total prize pool
    uint256 public prizePool = 0;

    /// ============ Events ============

    event Draw(address indexed player, uint256 fee, uint256 score);
    event Sabotage(
        address indexed saboteur,
        address indexed victim,
        uint256 fee,
        uint256 score
    );
    event Payout(address indexed winner, uint256 amount);

    constructor() {
        _gameStart = block.timestamp;
        _totalPlayers = 0;
    }

    /// ============ Functions ============

    function drawNumber() external payable {
        // Ensure game is live
        require(isLiveGame(), "Cannot draw number while game not live.");

        // Ensure fee paid
        require(msg.value >= fee, "Must pay minimum fee to draw a number.");

        // Check if new player
        if (scores[msg.sender] <= 0) {
            players[_totalPlayers] = msg.sender;
            _totalPlayers += 1;
        }

        // TODO chainlink random number
        uint256 score = (block.number % maxNum) + 1;

        // Update score
        scores[msg.sender] = score;

        emit Draw(msg.sender, msg.value, score);
    }

    function sabotage(address victim) external payable {
        // TODO check gas diffference in multiple state reads for victim[score]

        // Ensure game is live
        require(isLiveGame(), "Cannot sabotage while game is not live.");

        // Ensure fee paid
        require(
            msg.value >= fee * sabotagePremium,
            "Must pay min fee * sabotage premium to sabotage a player."
        );

        // Ensure victim is a player
        require(scores[victim] > 0, "Victim must be a player.");

        // Ensure saboteur is a player
        require(scores[msg.sender] > 0, "Saboteur must be a player.");

        // TODO random number to sabotage (should be less) within a smaller bound
        uint256 sabotageAmount = getSabotageAmount();
        uint256 newScore = min(1, scores[victim] - sabotageAmount);
        scores[victim] = newScore;

        // Increase victim earnings
        earnings[victim] += msg.value / sabotageFeePortion;

        emit Sabotage(msg.sender, victim, msg.value, newScore);
    }

    /// @notice Returns winner, if first time pays founder's fee and sets prizePool
    function closeGame() external {
        require(!isLiveGame(), "Cannot close game until game is over.");

        require(!gameClosed, "Game has already been closed.");

        gameClosed = true;

        // Pay creator fee
        payable(creatorAddress).transfer(
            address(this).balance / creatorFeePortion
        );

        // Find number of winners
        uint256 currentMax = 0;
        uint256 numWinners = 0;
        for (uint256 i = 0; i < _totalPlayers; i++) {
            if (scores[players[i]] > currentMax) {
                numWinners = 1;
                currentMax = scores[players[i]];
            }
            if (scores[players[i]] == currentMax) {
                numWinners++;
            }
        }

        // Pay winners
        uint256 winnings = address(this).balance / numWinners;
        for (uint256 i = 0; i < _totalPlayers; i++) {
            if (scores[players[i]] == currentMax) {
                earnings[players[i]] += winnings;
            }
        }
    }

    function claimEarnings() external {
        require(
            gameClosed,
            "Game must be closed before earnings can be claimed."
        );
        uint256 payout = earnings[msg.sender];
        delete earnings[msg.sender];
        payable(msg.sender).transfer(payout);
        emit Payout(msg.sender, payout);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        if (a - b <= 0) {
            return a;
        }
        return b;
    }

    function getSabotageAmount() private view returns (uint256) {
        uint256 rand = block.number;
        return rand % (maxNum / 2);
    }

    function isLiveGame() private view returns (bool) {
        return block.timestamp < _gameStart + gameLength * 86400;
    }
}
