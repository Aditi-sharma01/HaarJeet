
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title HaarJeet - Simple coin-flip betting game (beginner Solidity project)
/// @author ...
/// @notice Educational example only. Not for real-money use.
/// @dev Randomness is insecure; for production use Chainlink VRF or similar.

contract HaarJeet {
    address public owner;
    uint8 public feePercent;     // fee percentage taken by the house
    uint256 public minBet;
    uint256 public maxBet;
    bool public paused;

    bool private locked; // simple reentrancy guard

    event BetPlaced(address indexed player, uint256 amount, uint8 choice);
    event BetResult(address indexed player, uint256 amount, bool won, uint8 outcome, uint256 payout);
    event Withdraw(address indexed to, uint256 amount);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event FeeUpdated(uint8 oldFee, uint8 newFee);
    event Paused(bool paused);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    modifier notPaused() {
        require(!paused, "Game is paused");
        _;
    }

    modifier noReentrant() {
        require(!locked, "Reentrancy blocked");
        locked = true;
        _;
        locked = false;
    }

    constructor(uint8 _feePercent, uint256 _minBet, uint256 _maxBet) {
        require(_feePercent <= 100, "Invalid fee");
        require(_minBet > 0 && _minBet <= _maxBet, "Invalid bet limits");

        owner = msg.sender;
        feePercent = _feePercent;
        minBet = _minBet;
        maxBet = _maxBet;
        paused = false;
    }

    /// @notice Place a bet (choose 0 or 1)
    function placeBet(uint8 choice) external payable notPaused noReentrant {
        require(choice == 0 || choice == 1, "Choice must be 0 or 1");
        require(msg.value >= minBet && msg.value <= maxBet, "Bet outside limits");

        emit BetPlaced(msg.sender, msg.value, choice);

        // Simple pseudo-randomness (insecure)
        uint8 outcome = uint8(_pseudoRandom() % 2); // 🔧 fixed line

        bool won = (choice == outcome);
        uint256 payout = 0;

        if (won) {
            uint256 gross = msg.value * 2; // potential payout
            payout = (gross * (100 - feePercent)) / 100;

            require(address(this).balance >= payout, "Not enough funds in contract");

            (bool sent, ) = payable(msg.sender).call{value: payout}("");
            require(sent, "Payout failed");
        }

        emit BetResult(msg.sender, msg.value, won, outcome, payout);
    }

    /// @dev Very basic pseudo-random generator (not secure)
    function _pseudoRandom() internal view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(blockhash(block.number - 1), block.timestamp, msg.sender)
            )
        );
    }

    /// @notice Deposit ETH into the contract to fund payouts
    receive() external payable {}
    fallback() external payable {}

    /// @notice Owner can withdraw contract funds
    function withdraw(uint256 amount, address payable to) external onlyOwner noReentrant {
        require(amount <= address(this).balance, "Insufficient balance");
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "Withdraw failed");
        emit Withdraw(to, amount);
    }

    /// @notice Change the fee percentage
    function setFeePercent(uint8 _feePercent) external onlyOwner {
        require(_feePercent <= 100, "Invalid fee");
        emit FeeUpdated(feePercent, _feePercent);
        feePercent = _feePercent;
    }

    /// @notice Adjust min/max bet
    function setBetLimits(uint256 _minBet, uint256 _maxBet) external onlyOwner {
        require(_minBet > 0 && _minBet <= _maxBet, "Invalid limits");
        minBet = _minBet;
        maxBet = _maxBet;
    }

    /// @notice Pause or unpause the game
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit Paused(_paused);
    }

    /// @notice Transfer ownership
    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnerChanged(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Check how much ETH is in the contract
    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
