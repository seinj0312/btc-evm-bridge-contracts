// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <=0.8.4;

import "./interfaces/IBitcoinRelay.sol";

abstract contract BitcoinRelayStorage is IBitcoinRelay {

    // Public variables
    uint constant ONE_HUNDRED_PERCENT = 10000;
    uint constant MAX_FINALIZATION_PARAMETER = 432; // Roughly 3 days
    uint constant MAX_ALLOWED_GAP = 90 minutes;
    // ^ This is to prevent the submission of a Bitcoin block header with a timestamp 
    // that is more than 90 minutes ahead of the network's timestamp. Without this check,
    // the attacker could manipulate the difficulty target of a new epoch

    uint public override initialHeight;
    uint public override lastSubmittedHeight;
    uint public override finalizationParameter;
    uint public override rewardAmountInTDT;
    uint public override relayerPercentageFee; // A number between [0, 10000)
    uint public override submissionGasUsed; // Gas used for submitting a block header
    uint public override epochLength;
    uint public override baseQueries;
    uint public override currentEpochQueries;
    uint public override lastEpochQueries;
    address public override TeleportDAOToken;
    bytes32 public override relayGenesisHash; // Initial block header of relay

    // Internal variables
    mapping(uint => IBitcoinRelay.blockHeader[]) internal chain; // Height => list of block headers
    mapping(bytes32 => bytes32) internal previousBlock; // Block header hash => parent header hash
    mapping(bytes32 => uint256) internal blockHeight; // Block header hash => block height
}