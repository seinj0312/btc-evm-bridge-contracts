// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.8.4;

interface ICCExchangeRouter {
    // Structures

    /// @notice                    Structure for recording cross-chain exchange requests
    /// @param appId               Application id that user wants to use (defines the exchange that user wants to use)
    /// @param inputAmount         Amount of locked BTC on source chain
    /// @param outputAmount        Amount of output token
    /// @param isFixedToken        True if amount of input token is fixed
    /// @param recipientAddress    Address of exchange recipient
    /// @param fee                 Amount of fee that is paid to Teleporter (tx, relayer and teleporter fees)
    /// @param isUsed              Whether the tx is used or not
    /// @param path                Path from input token to output token
    /// @param deadline            Deadline of exchanging tokens
    /// @param speed               Speed of the request (normal or instant)
    struct ccExchangeRequest {
        uint appId;
        uint inputAmount;
        uint outputAmount;
        bool isFixedToken;
        address recipientAddress;
        uint fee;
        bool isUsed;
        address[] path;
        uint deadline;
        uint speed;
    }

    // Events

    /// @notice                     Emits when a cc exchange request gets done
    /// @param user                 Exchange recipient address
    /// @param speed                Speed of the request (normal or instant)
    /// @param teleporter          Address of teleporter who submitted the request
    /// @param teleporterFee        Amount of fee that is paid to Teleporter (tx, relayer and teleporter fees)
    event CCExchange(
        bytes lockerLockingScript,
        uint lockerScriptType,
        address lockerTargetAddress,
        address indexed user,
        address[2] inputAndOutputToken,
        uint[2] inputAndOutputAmount,
        uint indexed speed,
        address teleporter,
        uint teleporterFee,
        bytes32 bitcoinTxId,
        uint appId
    );

    /// @notice                     Emits when a cc exchange request fails
    /// @dev                        In this case, instead of excahnging tokens,
    ///                             we mint teleBTC and send it to the user
    /// @param recipientAddress     Exchange recipient address
    /// @param speed                Speed of the request (normal or instant)
    /// @param teleporter          Address of teleporter who submitted the request
    /// @param teleporterFee        Amount of fee that is paid to Teleporter (tx, relayer and teleporter fees)
    event FailedCCExchange(
        bytes lockerLockingScript,
        uint lockerScriptType,
        address lockerTargetAddress,
        address indexed recipientAddress,
        address[2] inputAndOutputToken,
        uint[2] inputAndOutputAmount,
        uint indexed speed,
        address teleporter,
        uint teleporterFee,
        bytes32 bitcoinTxId,
        uint appId
    );

    /// @notice                      Emits when appId for an exchange connector is set
    /// @param appId                 Assigned application id to exchange
    /// @param exchangeConnector     Address of exchange connector contract
    event SetExchangeConnector(
        uint appId,
        address exchangeConnector
    );

    /// @notice                     Emits when changes made to relay address
    event NewRelay (
        address oldRelay, 
        address newRelay
    );

    /// @notice                     Emits when changes made to InstantRouter address
    event NewInstantRouter (
        address oldInstantRouter, 
        address newInstantRouter
    );

    /// @notice                     Emits when changes made to Lockers address
    event NewLockers (
        address oldLockers, 
        address newLockers
    );

    /// @notice                     Emits when changes made to TeleBTC address
    event NewTeleBTC (
        address oldTeleBTC, 
        address newTeleBTC
    );

    /// @notice                     Emits when changes made to protocol percentage fee
    event NewProtocolPercentageFee (
        uint oldProtocolPercentageFee, 
        uint newProtocolPercentageFee
    );

    /// @notice                     Emits when changes made to Treasury address
    event NewTreasury (
        address oldTreasury, 
        address newTreasury
    );

    // Read-only functions
    
    function startingBlockNumber() external view returns (uint);

    function protocolPercentageFee() external view returns (uint);
    
    function chainId() external view returns (uint);

    function relay() external view returns (address);

    function instantRouter() external view returns (address);

    function lockers() external view returns (address);

    function teleBTC() external view returns (address);

    function isRequestUsed(bytes32 _txId) external view returns (bool);

    function exchangeConnector(uint appId) external view returns (address);

    function treasury() external view returns (address);

    // State-changing functions

    function setRelay(address _relay) external;

    function setInstantRouter(address _instantRouter) external;

    function setLockers(address _lockers) external;

    function setTeleBTC(address _teleBTC) external;

    function setExchangeConnector(uint _appId, address _exchangeConnector) external;

	function setTreasury(address _treasury) external;

	function setProtocolPercentageFee(uint _protocolPercentageFee) external;

    function ccExchange(
        // Bitcoin tx
        bytes4 _version,
        bytes memory _vin,
        bytes calldata _vout,
        bytes4 _locktime,
        // Bitcoin block number
        uint256 _blockNumber,
        // Merkle proof
        bytes calldata _intermediateNodes,
        uint _index,
        bytes calldata _lockerLockingScript
    ) external payable returns(bool);
}