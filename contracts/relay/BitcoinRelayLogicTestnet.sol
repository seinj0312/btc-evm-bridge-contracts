// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BitcoinRelayLogic.sol";
import "../libraries/TypedMemView.sol";
import "../libraries/BitcoinHelper.sol";

contract BitcoinRelayLogicTestnet is BitcoinRelayLogic {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using BitcoinHelper for bytes29;

    /// @notice Always return 1 in testnet
    function getBlockHeaderFee(uint256, uint256)
        external
        view
        override
        returns (uint256)
    {
        return 1;
    }

    /// @notice Always return true in testnet
    function checkTxProof(
        bytes32 _txid, // In LE form
        uint256 _blockHeight,
        bytes calldata,
        uint256
    ) external payable override nonReentrant whenNotPaused returns (bool) {
        require(msg.value >= 1, "BitcoinRelay: fee is not enough");
        Address.sendValue(payable(_msgSender()), msg.value - 1);
        emit NewQuery(_txid, _blockHeight, 1);
        return true;
    }

    /// @notice Adds header to storage
    /// @dev Many checks have been removed for testnet
    function addHeaders(bytes calldata _anchor, bytes calldata _headers)
        external
        override
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        bytes29 _headersView = _headers.ref(0).tryAsHeaderArray();
        bytes29 _anchorView = _anchor.ref(0).tryAsHeader();
        return _addHeaders(_anchorView, _headersView, false);
    }

    /// @notice Add headers to storage
    /// @dev Same as addHeaders (no retargeting checks in testnet)
    function addHeadersWithRetarget(
        bytes calldata _oldPeriodStartHeader,
        bytes calldata _oldPeriodEndHeader,
        bytes calldata _headers
    ) external override nonReentrant whenNotPaused returns (bool) {
        bytes29 _oldStart = _oldPeriodStartHeader.ref(0).tryAsHeader();
        bytes29 _oldEnd = _oldPeriodEndHeader.ref(0).tryAsHeader();
        bytes29 _headersView = _headers.ref(0).tryAsHeaderArray();
        return _addHeadersWithRetarget(_oldStart, _oldEnd, _headersView);
    }

    function _addHeaders(
        bytes29 _anchor,
        bytes29 _headers,
        bool
    ) internal override returns (bool) {
        // Extract basic info
        bytes32 _previousHash = _anchor.hash256();
        uint256 _anchorHeight = _findHeight(_previousHash); // revert if the block is unknown
        uint256 _height;
        bytes32 _currentHash;

        for (uint256 i = 0; i < _headers.len() / 80; i++) {
            bytes29 _header = _headers.indexHeaderArray(i);
            _height = _anchorHeight + i + 1;
            _currentHash = _header.hash256();
            blockHeight[_currentHash] = _height;
            lastSubmittedHeight = _height;
            emit BlockAdded(_height, _currentHash, _previousHash, _msgSender());
            _previousHash = _currentHash;
        }
        return true;
    }

    function _addHeadersWithRetarget(
        bytes29,
        bytes29 _oldEnd,
        bytes29 _headers
    ) internal override returns (bool) {
        return _addHeaders(_oldEnd, _headers, true);
    }
}
