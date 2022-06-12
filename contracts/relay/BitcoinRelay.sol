pragma solidity ^0.7.6;

/** @title Relay */
/** @author Summa (https://summa.one) */

import "../libraries/SafeMath.sol";
import "../libraries/TypedMemView.sol";
import "../libraries/ViewBTC.sol";
import "../libraries/ViewSPV.sol";
import "./interfaces/IBitcoinRelay.sol";
import "../routers/interfaces/IExchangeRouter.sol";
import "../erc20/interfaces/IERC20.sol";
import "hardhat/console.sol";

contract BitcoinRelay is IBitcoinRelay {
    using SafeMath for uint256;
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using ViewBTC for bytes29;
    using ViewSPV for bytes29;

    /* using BytesLib for bytes;
    using BTCUtils for bytes;
    using ValidateSPV for bytes; */

    // How often do we store the height?
    // A higher number incurs less storage cost, but more lookup cost
    // uint32 public constant HEIGHT_INTERVAL = 4;
    uint32 public constant HEIGHT_INTERVAL = 1;
    uint public override initialHeight;
    uint public override lastSubmittedHeight;
    uint public override finalizationParameter;

    bytes32 internal relayGenesis;
    bytes32 internal bestKnownDigest;
    bytes32 internal lastReorgCommonAncestor;
    mapping (bytes32 => bytes32) internal previousBlock;
    mapping (bytes32 => uint256) internal blockHeight;
    mapping (uint => blockHeader[]) public chain;
    address public override owner;

    uint256 internal currentEpochDiff;
    uint256 internal prevEpochDiff;

    // reward parameters
    address public override TeleportDAOToken;
    uint public override feeRatio; // multiplied by 100
    uint public override submissionGasUsed;
    uint public override epochLength;
    uint public override lastEpochQueries;
    uint public override baseQueries;
    uint public override lastBuyBack;
    uint public override buyBackPeriod;
    address public override exchangeRouter;
    address public override WAVAX;
    mapping (uint => uint) private numberOfQueries;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    /// @notice                   Gives a starting point for the relay
    /// @dev                      We don't check this AT ALL really. Don't use relays with bad genesis
    /// @param  _genesisHeader    The starting header
    /// @param  _height           The starting height
    /// @param  _periodStart      The hash of the first header in the genesis epoch
    constructor(
        bytes memory _genesisHeader,
        uint256 _height,
        bytes32 _periodStart,
        address _TeleportDAOToken,
        address _exchangeRouter
    ) public {
        bytes29 _genesisView = _genesisHeader.ref(0).tryAsHeader();
        require(_genesisView.notNull(), "Stop being dumb");
        bytes32 _genesisDigest = _genesisView.hash256();
        // add the initial block header to the chain
        blockHeader memory newBlockHeader;
        newBlockHeader.selfHash = _genesisDigest;
        newBlockHeader.merkleRoot = _genesisView.merkleRoot();
        chain[_height].push(newBlockHeader);

        // require(
        //     _periodStart & bytes32(0x0000000000000000000000000000000000000000000000000000000000ffffff) == bytes32(0),
        //     "Period start hash does not have work. Hint: wrong byte order?");
        relayGenesis = _genesisDigest;
        bestKnownDigest = _genesisDigest;
        lastReorgCommonAncestor = _genesisDigest;
        blockHeight[_genesisDigest] = _height;
        console.log("_genesisDigest");
        console.logBytes32(_genesisDigest);
        console.log("_height", _height);

        blockHeight[_periodStart] = _height.sub(_height % 2016);
        currentEpochDiff = _genesisView.diff();

        // added parameters
        finalizationParameter = 1; // TODO: edit it
        lastSubmittedHeight = _height;
        initialHeight = _height;
        // reward parameters
        TeleportDAOToken = _TeleportDAOToken;
        feeRatio = 0; // TODO: edit it;
        epochLength = 1;
        baseQueries = epochLength;
        lastEpochQueries = baseQueries;
        buyBackPeriod = 2; // TODO: edit it
        submissionGasUsed = 100000; // TODO: edit it
        exchangeRouter = _exchangeRouter;

        if (exchangeRouter != address(0)) {
            WAVAX = IExchangeRouter(exchangeRouter).WAVAX(); // call exchangeRouter to get WAVAX address
        }
        owner = msg.sender;
    }

    fallback () external payable {
    }

    function changeOwner(address _owner) external override onlyOwner {
        owner = _owner;
    }

    function setFinalizationParameter(uint _finalizationParameter) external override onlyOwner {
        finalizationParameter = _finalizationParameter;
    }

    function setFeeRatio(uint _feeRatio) external override onlyOwner {
        feeRatio = _feeRatio;
    }

    function setEpochLength(uint _epochLength) external override onlyOwner {
        epochLength = _epochLength;
    }

    function setBuyBackPeriod(uint _buyBackPeriod) external override onlyOwner {
        buyBackPeriod = _buyBackPeriod;
    }

    function setBaseQueries(uint _baseQueries) external override onlyOwner {
        baseQueries = _baseQueries;
    }

    function setSubmissionGasUsed(uint _submissionGasUsed) external override onlyOwner {
        submissionGasUsed = _submissionGasUsed;
    }

    function setExchangeRouter(address _exchangeRouter) external override onlyOwner {
        exchangeRouter = _exchangeRouter;
    }

    /// @notice     Getter for currentEpochDiff
    /// @dev        This is updated when a new heavist header has a new diff
    /// @return     The difficulty of the bestKnownDigest
    function getCurrentEpochDifficulty() external view override returns (uint256) {
        return currentEpochDiff;
    }
    /// @notice     Getter for prevEpochDiff
    /// @dev        This is updated when a difficulty change is accepted
    /// @return     The difficulty of the previous epoch
    function getPrevEpochDifficulty() external view override returns (uint256) {
        return prevEpochDiff;
    }

    /// @notice     Getter for relayGenesis
    /// @dev        This is an initialization parameter
    /// @return     The hash of the first block of the relay
    function getRelayGenesis() public view override returns (bytes32) {
        return relayGenesis;
    }

    /// @notice     Getter for bestKnownDigest
    /// @dev        This updated only by calling markNewHeaviest
    /// @return     The hash of the best marked chain tip
    function getBestKnownDigest() public view override returns (bytes32) {
        return bestKnownDigest;
    }

    /// @notice     Getter for relayGenesis
    /// @dev        This is updated only by calling markNewHeaviest
    /// @return     The hash of the shared ancestor of the most recent fork
    function getLastReorgCommonAncestor() public view override returns (bytes32) {
        return lastReorgCommonAncestor;
    }

    /// @notice         Finds the height of a header by its digest
    /// @dev            Will fail if the header is unknown
    /// @param _digest  The header digest to search for
    /// @return         The height of the header, or error if unknown
    function findHeight(bytes32 _digest) external view override returns (uint256) {
        return _findHeight(_digest);
    }

    /// @notice         Finds an ancestor for a block by its digest
    /// @dev            Will fail if the header is unknown
    /// @param _digest  The header digest to search for
    /// @return         The height of the header, or error if unknown
    function findAncestor(bytes32 _digest, uint256 _offset) external view override returns (bytes32) {
        return _findAncestor(_digest, _offset);
    }

    /// @notice             Checks if a digest is an ancestor of the current one
    /// @dev                Limit the amount of lookups (and thus gas usage) with _limit
    /// @param _ancestor    The prospective ancestor
    /// @param _descendant  The descendant to check
    /// @param _limit       The maximum number of blocks to check
    /// @return             true if ancestor is at most limit blocks lower than descendant, otherwise false
    function isAncestor(bytes32 _ancestor, bytes32 _descendant, uint256 _limit) external view override returns (bool) {
        return _isAncestor(_ancestor, _descendant, _limit);
    }

    function checkTxProof (
        bytes32 txid, // in BE form
        uint blockHeight,
        bytes calldata intermediateNodes, // in LE form
        uint index,
        bool payWithTDT,
        uint neededConfirmations
    ) public view override returns (bool) {
        if (blockHeight + neededConfirmations < lastSubmittedHeight + 1) {
            for (uint i = 0; i < chain[blockHeight].length; i ++) {
                bytes32 _merkleRoot = revertBytes32(chain[blockHeight][i].merkleRoot);
                bytes29 intermediateNodes = intermediateNodes.ref(0).tryAsMerkleArray();
                bytes32 txIdLE = revertBytes32(txid);
                if (ViewSPV.prove(txIdLE, _merkleRoot, intermediateNodes, index)) {
                    // getFee(payWithTDT);
                    return true;
                }
            }
            require(false, "tx has not been included");
        } else {
            return false;
        }
    }

    function getFee (bool payWithTDT) internal {
        uint feeAmount;
        feeAmount = (submissionGasUsed*tx.gasprice*feeRatio*epochLength)/(100*lastEpochQueries);
        if (payWithTDT == false) {
            // require(msg.value >= feeAmount, "fee is not enough");
            if (msg.value >= feeAmount){
                msg.sender.send(feeAmount);
            }
        } else { // payWithTDT == true
            feeAmount = getFeeAmountInTDT(feeAmount);
            uint TDTBalance = IERC20(TeleportDAOToken).balanceOf(address(this));
            if (feeAmount > 0 && TDTBalance >= feeAmount) {
                IERC20(TeleportDAOToken).transferFrom(msg.sender, address(this), feeAmount); // tx.origin instead of msg.sender
            }
        }
    }

    /// @notice             Adds headers to storage after validating
    /// @dev                We check integrity and consistency of the header chain
    /// @param  _anchor     The header immediately preceeding the new chain
    /// @param  _headers    A tightly-packed list of 80-byte Bitcoin headers
    /// @return             True if successfully written, error otherwise
    function addHeaders(bytes calldata _anchor, bytes calldata _headers) external override returns (bool) {

        bytes29 _headersView = _headers.ref(0).tryAsHeaderArray();
        bytes29 _anchorView = _anchor.ref(0).tryAsHeader();

        require(_headersView.notNull(), "Header array length must be divisible by 80");
        require(_anchorView.notNull(), "Anchor must be 80 bytes");

        return _addHeaders(_anchorView, _headersView, false);
    }

    /// @notice                       Adds headers to storage, performs additional validation of retarget
    /// @dev                          Checks the retarget, the heights, and the linkage
    /// @param  _oldPeriodStartHeader The first header in the difficulty period being closed
    /// @param  _oldPeriodEndHeader   The last header in the difficulty period being closed
    /// @param  _headers              A tightly-packed list of 80-byte Bitcoin headers
    /// @return                       True if successfully written, error otherwise
    function addHeadersWithRetarget(
        bytes calldata _oldPeriodStartHeader,
        bytes calldata _oldPeriodEndHeader,
        bytes calldata _headers
    ) external override returns (bool) {
        bytes29 _oldStart = _oldPeriodStartHeader.ref(0).tryAsHeader();
        bytes29 _oldEnd = _oldPeriodEndHeader.ref(0).tryAsHeader();
        bytes29 _headersView = _headers.ref(0).tryAsHeaderArray();

        require(
            _oldStart.notNull() && _oldEnd.notNull() && _headersView.notNull(),
            "Bad args. Check header and array byte lengths."
        );

        return _addHeadersWithRetarget(_oldStart, _oldEnd, _headersView);
    }

    /// @notice                   Gives a starting point for the relay
    /// @dev                      We don't check this AT ALL really. Don't use relays with bad genesis
    /// @param  _ancestor         The digest of the most recent common ancestor
    /// @param  _currentBest      The 80-byte header referenced by bestKnownDigest
    /// @param  _newBest          The 80-byte header to mark as the new best
    /// @param  _limit            Limit the amount of traversal of the chain
    /// @return                   True if successfully updates bestKnownDigest, error otherwise
    function markNewHeaviest(
        bytes32 _ancestor,
        bytes calldata _currentBest,
        bytes calldata _newBest,
        uint256 _limit
    ) external override returns (bool) {
        bytes29 _new = _newBest.ref(0).tryAsHeader();
        bytes29 _current = _currentBest.ref(0).tryAsHeader();
        require(
            _new.notNull() && _current.notNull(),
            "Bad args. Check header and array byte lengths."
        );
        return _markNewHeaviest(_ancestor, _current, _new, _limit);
    }

    /// @notice             Adds headers to storage after validating
    /// @dev                We check integrity and consistency of the header chain
    /// @param  _anchor     The header immediately preceeding the new chain
    /// @param  _headers    A tightly-packed list of new 80-byte Bitcoin headers to record
    /// @param  _internal   True if called internally from addHeadersWithRetarget, false otherwise
    /// @return             True if successfully written, error otherwise
    function _addHeaders(bytes29 _anchor, bytes29 _headers, bool _internal) internal returns (bool) {

        // Extract basic info
        bytes32 _previousDigest = _anchor.hash256();
        console.log("_previousDigest");
        console.logBytes32(_previousDigest);

        uint256 _anchorHeight = _findHeight(_previousDigest);  /* NB: errors if unknown */
        console.log("_anchorHeight", _anchorHeight);
        uint256 _target = _headers.indexHeaderArray(0).target();

        // TODO: uncomment it
        // require(
        //     _internal || _anchor.target() == _target,
        //     "Unexpected retarget on external call"
        // );

        /*
        NB:
        1. check that the header has sufficient work
        2. check that headers are in a coherent chain (no retargets, hash links good)
        3. Store the block connection
        4. Store the height
        */
        uint256 _height;
        bytes32 _currentDigest;
        for (uint256 i = 0; i < _headers.len() / 80; i += 1) {

            bytes29 _header = _headers.indexHeaderArray(i);
            _height = _anchorHeight.add(i + 1);
            _currentDigest = _header.hash256();

            /* NB: we do still need to make chain level checks tho */
            // require(_header.target() == _target, "Target changed unexpectedly");
            require(_header.checkParent(_previousDigest), "Headers do not form a consistent chain");
            /*
            NB:
            if the block is already authenticated, we don't need to a work check
            Or write anything to state. This saves gas
            */
            // the below check prevents adding a replicated block header
            if (previousBlock[_currentDigest] == bytes32(0)) {
                require(
                    TypedMemView.reverseUint256(uint256(_currentDigest)) <= _target,
                    "Header work is insufficient"
                );
                previousBlock[_currentDigest] = _previousDigest;
                if (_height % HEIGHT_INTERVAL == 0) {
                    /*
                    NB: We store the height only every 4th header to save gas
                    */
                    blockHeight[_currentDigest] = _height;
                }
                addToChain(_header, _height);
            }
            _previousDigest = _currentDigest;
        }

        uint rewardAmount;
        bool isTDT;

        (rewardAmount, isTDT) = sendReward(msg.sender, _headers.len());

        emit BlockAdded(_height - _headers.len()/80 + 1, _height, msg.sender, rewardAmount, isTDT);

        return true;
    }

    function sendReward (address relayer, uint numberOfBlocks) internal returns (uint, bool) {
        uint rewardAmountInTNT = numberOfBlocks*submissionGasUsed*tx.gasprice*feeRatio/100; // TNT is target native token
        uint rewardAmountInTDT = getRewardAmountInTDT(rewardAmountInTNT);
        uint contractTDTBalance;
        if (TeleportDAOToken != address(0)) {
            contractTDTBalance = IERC20(TeleportDAOToken).balanceOf(address(this));
        } else {
            contractTDTBalance = 0;
        }
        uint contractTNTBalance = address(this).balance;
        if (rewardAmountInTDT <= contractTDTBalance && rewardAmountInTDT > 0) {
            // call ERC20 token contract to transfer reward tokens to the relayer
            IERC20(TeleportDAOToken).transfer(relayer, rewardAmountInTDT);
            return (rewardAmountInTDT, true);
        } else if (rewardAmountInTNT <= contractTNTBalance && rewardAmountInTNT > 0) {
            // transfer TNT from relay to relayer
            msg.sender.transfer(rewardAmountInTNT);
            return (rewardAmountInTNT, false);
        }
    }

    function getRewardAmountInTDT(uint rewardAmountInTNT) internal returns(uint) {
        // TODO: calculate the reward using the swap rate between the token and TDT
        return 0;
    }

    function getFeeAmountInTDT(uint feeAmount) internal returns(uint) {
        // TODO: calculate the fee using the swap rate between the token and TDT
        return 0;
    }

    function addToChain(bytes29 _header, uint _height) internal {
        // prevent relayers to submit too old block headers
        // TODO: replace 6 with a correct number

        console.log("lastSubmittedHeight: ", lastSubmittedHeight);
        console.log("_height: ", _height);

        require(_height + 2*finalizationParameter >= lastSubmittedHeight, "block header is too old");
        blockHeader memory newBlockHeader;
        newBlockHeader.selfHash = _header.hash256();
        newBlockHeader.parentHash = _header.parent();
        newBlockHeader.merkleRoot = _header.merkleRoot();
        chain[_height].push(newBlockHeader);
        if(_height > lastSubmittedHeight){
            lastSubmittedHeight++;
            pruneChain();
        }
    }

    function pruneChain() internal {
        if ((lastSubmittedHeight - initialHeight) >= finalizationParameter){
            uint idx = finalizationParameter;
            uint currentHeight = lastSubmittedHeight;
            uint stableIdx = 0;
            while (idx > 0) {
                // bytes29 header = chain[currentHeight][stableIdx];
                bytes32 parentHeaderHash = chain[currentHeight][stableIdx].parentHash;
                stableIdx = findIndex(parentHeaderHash, currentHeight-1);
                idx--;
                currentHeight--;
            }
            // keep the finalized block header and delete rest of headers
            chain[currentHeight][0] = chain[currentHeight][stableIdx];
            if(chain[currentHeight].length > 1){
                deleteHeight(currentHeight);
            }
        }
    }

    function findIndex(bytes32 headerHash, uint height) internal returns(uint) {
        for(uint index = 0; index < chain[height].length; index ++) {
            if(headerHash == chain[height][index].selfHash) {
                return index;
            }
        }
        return 0;
    }

    function deleteHeight(uint height) internal {
        uint idx = 1;
        while(idx < chain[height].length){
            delete chain[height][idx];
            idx++;
        }
    }

    /// @notice                       Adds headers to storage, performs additional validation of retarget
    /// @dev                          Checks the retarget, the heights, and the linkage
    /// @param  _oldStart             The first header in the difficulty period being closed
    /// @param  _oldEnd               The last header in the difficulty period being closed
    /// @param  _headers              A tightly-packed list of 80-byte Bitcoin headers
    /// @return                       True if successfully written, error otherwise
    function _addHeadersWithRetarget(
        bytes29 _oldStart,
        bytes29 _oldEnd,
        bytes29 _headers
    ) internal returns (bool) {

        /* NB: requires that both blocks are known */
        uint256 _startHeight = _findHeight(_oldStart.hash256());
        uint256 _endHeight = _findHeight(_oldEnd.hash256());

        /* NB: retargets should happen at 2016 block intervals */
        require(
            _endHeight % 2016 == 2015,
            "Must provide the last header of the closing difficulty period");
        require(
            _endHeight == _startHeight.add(2015),
            "Must provide exactly 1 difficulty period");
        require(
            _oldStart.diff() == _oldEnd.diff(),
            "Period header difficulties do not match");

        /* NB: This comparison looks weird because header nBits encoding truncates targets */
        bytes29 _newStart = _headers.indexHeaderArray(0);
        uint256 _actualTarget = _newStart.target();
        uint256 _expectedTarget = ViewBTC.retargetAlgorithm(
            _oldStart.target(),
            _oldStart.time(),
            _oldEnd.time()
        );
        require(
            (_actualTarget & _expectedTarget) == _actualTarget,
            "Invalid retarget provided");

        // If the current known prevEpochDiff doesn't match, and this old period is near the chaintip/
        // update the stored prevEpochDiff
        // Don't update if this is a deep past epoch
        uint256 _oldDiff = _oldStart.diff();
        if (prevEpochDiff != _oldDiff && _endHeight > _findHeight(bestKnownDigest).sub(2016)) {
            prevEpochDiff = _oldDiff;
        }

        // Pass all but the first through to be added
        return _addHeaders(_oldEnd, _headers, true);
    }

    /// @notice         Finds the height of a header by its digest
    /// @dev            Will fail if the header is unknown
    /// @param _digest  The header digest to search for
    /// @return         The height of the header
    function _findHeight(bytes32 _digest) internal view returns (uint256) {
        uint256 _height = 0;
        bytes32 _current = _digest;
        for (uint256 i = 0; i < HEIGHT_INTERVAL + 1; i = i.add(1)) {
            _height = blockHeight[_current];
            if (_height == 0) {
                _current = previousBlock[_current];
            } else {
                return _height.add(i);
            }
        }
        revert("Unknown block");
    }

    /// @notice         Finds an ancestor for a block by its digest
    /// @dev            Will fail if the header is unknown
    /// @param _digest  The header digest to search for
    /// @return         The height of the header, or error if unknown
    function _findAncestor(bytes32 _digest, uint256 _offset) internal view returns (bytes32) {
        console.log("_findAncestor");
        console.logBytes32(_digest);

        bytes32 _current = _digest;

        console.logBytes32(_current);

        for (uint256 i = 0; i < _offset; i = i.add(1)) {
            _current = previousBlock[_current];
        }

        console.logBytes32(_current);

        require(_current != bytes32(0), "Unknown ancestor");
        return _current;
    }

    /// @notice             Checks if a digest is an ancestor of the current one
    /// @dev                Limit the amount of lookups (and thus gas usage) with _limit
    /// @param _ancestor    The prospective ancestor
    /// @param _descendant  The descendant to check
    /// @param _limit       The maximum number of blocks to check
    /// @return             true if ancestor is at most limit blocks lower than descendant, otherwise false
    function _isAncestor(bytes32 _ancestor, bytes32 _descendant, uint256 _limit) internal view returns (bool) {
        bytes32 _current = _descendant;
        /* NB: 200 gas/read, so gas is capped at ~200 * limit */
        for (uint256 i = 0; i < _limit; i = i.add(1)) {
            if (_current == _ancestor) {
                return true;
            }
            _current = previousBlock[_current];
        }
        return false;
    }

    /// @notice                   Marks the new best-known chain tip
    /// @param  _ancestor         The digest of the most recent common ancestor
    /// @param  _current          The 80-byte header referenced by bestKnownDigest
    /// @param  _new              The 80-byte header to mark as the new best
    /// @param  _limit            Limit the amount of traversal of the chain
    /// @return                   True if successfully updates bestKnownDigest, error otherwise
    function _markNewHeaviest(
        bytes32 _ancestor,
        bytes29 _current,  // Header
        bytes29 _new,      // Header
        uint256 _limit
    ) internal returns (bool) {
        require(_limit <= 2016, "Requested limit is greater than 1 difficulty period");

        bytes32 _newBestDigest = _new.hash256();
        bytes32 _currentBestDigest = _current.hash256();
        require(_currentBestDigest == bestKnownDigest, "Passed in best is not best known");
        require(
            previousBlock[_newBestDigest] != bytes32(0),
            "New best is unknown"
        );
        require(
            _isMostRecentAncestor(_ancestor, bestKnownDigest, _newBestDigest, _limit),
            "Ancestor must be heaviest common ancestor"
        );
        require(
            _heaviestFromAncestor(_ancestor, _current, _new) == _newBestDigest,
            "New best hash does not have more work than previous"
        );

        bestKnownDigest = _newBestDigest;
        lastReorgCommonAncestor = _ancestor;

        uint256 _newDiff = _new.diff();
        if (_newDiff != currentEpochDiff) {
            currentEpochDiff = _newDiff;
        }

        emit NewTip(
            _currentBestDigest,
            _newBestDigest,
            _ancestor);
        return true;
    }

    function isMostRecentAncestor(
        bytes32 _ancestor,
        bytes32 _left,
        bytes32 _right,
        uint256 _limit
    ) external view returns (bool) {
        return _isMostRecentAncestor(_ancestor, _left, _right, _limit);
    }

    /// @notice             Checks if a digest is an ancestor of the current one
    /// @dev                Limit the amount of lookups (and thus gas usage) with _limit
    /// @param _ancestor    The prospective shared ancestor
    /// @param _left        A chain tip
    /// @param _right       A chain tip
    /// @param _limit       The maximum number of blocks to check
    /// @return             true if it is the most recent common ancestor within _limit, false otherwise
    function _isMostRecentAncestor(
        bytes32 _ancestor,
        bytes32 _left,
        bytes32 _right,
        uint256 _limit
    ) internal view returns (bool) {
        /* NB: sure why not */
        if (_ancestor == _left && _ancestor == _right) {
            return true;
        }

        bytes32 _leftCurrent = _left;
        bytes32 _rightCurrent = _right;
        bytes32 _leftPrev = _left;
        bytes32 _rightPrev = _right;

        for(uint256 i = 0; i < _limit; i = i.add(1)) {
            if (_leftPrev != _ancestor) {
                _leftCurrent = _leftPrev;  // cheap
                _leftPrev = previousBlock[_leftPrev];  // expensive
            }
            if (_rightPrev != _ancestor) {
                _rightCurrent = _rightPrev;  // cheap
                _rightPrev = previousBlock[_rightPrev];  // expensive
            }
        }
        if (_leftCurrent == _rightCurrent) {return false;} /* NB: If the same, they're a nearer ancestor */
        if (_leftPrev != _rightPrev) {return false;} /* NB: Both must be ancestor */
        return true;
    }

    function heaviestFromAncestor(
        bytes32 _ancestor,
        bytes calldata _left,
        bytes calldata _right
    ) external view returns (bytes32) {
        return _heaviestFromAncestor(
            _ancestor,
            _left.ref(0).tryAsHeader(),
            _right.ref(0).tryAsHeader()
        );
    }

    /// @notice             Decides which header is heaviest from the ancestor
    /// @dev                Does not support reorgs above 2017 blocks (:
    /// @param _ancestor    The prospective shared ancestor
    /// @param _left        A chain tip
    /// @param _right       A chain tip
    /// @return             true if it is the most recent common ancestor within _limit, false otherwise
    function _heaviestFromAncestor(
        bytes32 _ancestor,
        bytes29 _left,
        bytes29 _right
    ) internal view returns (bytes32) {
        uint256 _ancestorHeight = _findHeight(_ancestor);
        uint256 _leftHeight = _findHeight(_left.hash256());
        uint256 _rightHeight = _findHeight(_right.hash256());

        require(
            _leftHeight >= _ancestorHeight && _rightHeight >= _ancestorHeight,
            "A descendant height is below the ancestor height");

        /* NB: we can shortcut if one block is in a new difficulty window and the other isn't */
        uint256 _nextPeriodStartHeight = _ancestorHeight.add(2016).sub(_ancestorHeight % 2016);
        bool _leftInPeriod = _leftHeight < _nextPeriodStartHeight;
        bool _rightInPeriod = _rightHeight < _nextPeriodStartHeight;

        /*
        NB:
        1. Left is in a new window, right is in the old window. Left is heavier
        2. Right is in a new window, left is in the old window. Right is heavier
        3. Both are in the same window, choose the higher one
        4. They're in different new windows. Choose the heavier one
        */
        if (!_leftInPeriod && _rightInPeriod) {return _left.hash256();}
        if (_leftInPeriod && !_rightInPeriod) {return _right.hash256();}
        if (_leftInPeriod && _rightInPeriod) {
            return _leftHeight >= _rightHeight ? _left.hash256() : _right.hash256();
        } else {  // if (!_leftInPeriod && !_rightInPeriod) {
            if (((_leftHeight % 2016).mul(_left.diff())) <
                (_rightHeight % 2016).mul(_right.diff())) {
                return _right.hash256();
            } else {
                return _left.hash256();
            }
        }
    }

    function revertBytes32 (bytes32 input) internal view returns(bytes32) {
        bytes memory temp;
        bytes32 result;
        for (uint i = 0; i < 32; i++) {
            temp = abi.encodePacked(temp, input[31-i]);
        }
        assembly {
            result := mload(add(temp, 32))
        }
        return result;
    }

    function revertBytes (bytes memory input) internal returns(bytes memory) {
        bytes memory result;
        uint len = input.length;
        for (uint i = 0; i < len; i++) {
            result = abi.encodePacked(result, input[len-i-1]);
        }
        return result;
    }

    function calculateTxId (
        bytes4 _version,
        bytes memory _vin,
        bytes memory _vout,
        bytes4 _locktime
    ) external view override returns(bytes32) {
        bytes32 inputHash1 = sha256(abi.encodePacked(_version, _vin, _vout, _locktime));
        bytes32 inputHash2 = sha256(abi.encodePacked(inputHash1));
        console.log("inputHash1");
        console.logBytes32(inputHash1);

        console.log("inputHash2");
        console.logBytes32(inputHash2);
        return inputHash2;
    }

    function getBlockHeaderHash (uint height, uint index) external override returns(bytes32) {
        return revertBytes32(chain[height][index].selfHash);
    }

    function getNumberOfSubmittedHeaders (uint height) external view override returns (uint) {
        return chain[height].length;
    }
}
