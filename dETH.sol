// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC20, WETH} from "@solady/src/tokens/WETH.sol";

/// @notice Delayed ethereum token
/// @author z0r0z.eth for nani.eth
contract dETH is WETH {
    event Log(bytes32 transferId);

    uint256 constant public DELAY = 1 days;

    error TransferFinalized();

    struct PendingTransfer {
        address from;
        address to;
        uint160 amount;
        uint96 timestamp;
    }

    mapping(bytes32 transferId => PendingTransfer) public pendingTransfers;

    constructor() payable {}

    function name() public pure override(WETH) returns (string memory) {
        return "Delayed Ether";
    }

    function symbol() public pure override(WETH) returns (string memory) {
        return "dETH";
    }

    function depositTo(address to) public payable {
        bytes32 transferId = keccak256(
            abi.encodePacked(msg.sender, to, msg.value, block.timestamp)
        );
        
        pendingTransfers[transferId] = PendingTransfer({
            from: msg.sender,
            to: to,
            amount: uint160(msg.value),
            timestamp: uint96(block.timestamp)
        });

        emit Log(transferId);

        _mint(to, msg.value);
    }

    function transfer(address to, uint256 amount) public override(ERC20) returns (bool) {
        bytes32 transferId = keccak256(
            abi.encodePacked(msg.sender, to, amount, block.timestamp)
        );
        
        pendingTransfers[transferId] = PendingTransfer({
            from: msg.sender,
            to: to,
            amount: uint160(amount),
            timestamp: uint96(block.timestamp)
        });

        emit Log(transferId);

        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override(ERC20) returns (bool) {
        bytes32 transferId = keccak256(
            abi.encodePacked(from, to, amount, block.timestamp)
        );
        
        pendingTransfers[transferId] = PendingTransfer({
            from: from,
            to: to,
            amount: uint160(amount),
            timestamp: uint96(block.timestamp)
        });

        emit Log(transferId);

        return super.transferFrom(from, to, amount);
    }

    function reverse(bytes32 transferId) public {
        unchecked {
            PendingTransfer storage pt = pendingTransfers[transferId];
            
            if (block.timestamp > pt.timestamp + DELAY) 
                revert TransferFinalized();
            if (msg.sender != pt.from) 
                _spendAllowance(pt.from, msg.sender, pt.amount);

            _transfer(pt.to, pt.from, pt.amount);
            
            delete pendingTransfers[transferId];
        }
    }
}