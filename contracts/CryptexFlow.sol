// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CryptexFlow
 * @dev A decentralized streaming payment protocol for continuous value transfer
 * @notice This contract enables users to create payment streams that flow over time
 */
contract CryptexFlow {
    
    struct Stream {
        address sender;
        address recipient;
        uint256 depositAmount;
        uint256 startTime;
        uint256 stopTime;
        uint256 ratePerSecond;
        uint256 withdrawnAmount;
        bool isActive;
    }
    
    mapping(uint256 => Stream) public streams;
    uint256 public nextStreamId;
    
    event StreamCreated(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        uint256 depositAmount,
        uint256 startTime,
        uint256 stopTime
    );
    
    event StreamWithdrawn(
        uint256 indexed streamId,
        address indexed recipient,
        uint256 amount
    );
    
    event StreamCancelled(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        uint256 senderBalance,
        uint256 recipientBalance
    );
    
    /**
     * @dev Creates a new payment stream
     * @param recipient Address receiving the streamed payments
     * @param duration Duration of the stream in seconds
     * @return streamId The ID of the newly created stream
     */
    function createStream(address recipient, uint256 duration) external payable returns (uint256) {
        require(recipient != address(0), "Invalid recipient");
        require(recipient != msg.sender, "Cannot stream to yourself");
        require(msg.value > 0, "Deposit must be greater than zero");
        require(duration > 0, "Duration must be greater than zero");
        
        uint256 startTime = block.timestamp;
        uint256 stopTime = startTime + duration;
        uint256 ratePerSecond = msg.value / duration;
        
        require(ratePerSecond > 0, "Rate per second must be greater than zero");
        
        uint256 streamId = nextStreamId;
        
        streams[streamId] = Stream({
            sender: msg.sender,
            recipient: recipient,
            depositAmount: msg.value,
            startTime: startTime,
            stopTime: stopTime,
            ratePerSecond: ratePerSecond,
            withdrawnAmount: 0,
            isActive: true
        });
        
        nextStreamId++;
        
        emit StreamCreated(streamId, msg.sender, recipient, msg.value, startTime, stopTime);
        
        return streamId;
    }
    
    /**
     * @dev Calculates the available balance for withdrawal from a stream
     * @param streamId The ID of the stream
     * @return The amount available for withdrawal
     */
    function balanceOf(uint256 streamId) public view returns (uint256) {
        Stream memory stream = streams[streamId];
        require(stream.isActive || stream.depositAmount > 0, "Stream does not exist");
        
        if (block.timestamp <= stream.startTime) {
            return 0;
        }
        
        uint256 elapsedTime;
        if (block.timestamp >= stream.stopTime) {
            elapsedTime = stream.stopTime - stream.startTime;
        } else {
            elapsedTime = block.timestamp - stream.startTime;
        }
        
        uint256 totalStreamed = elapsedTime * stream.ratePerSecond;
        return totalStreamed - stream.withdrawnAmount;
    }
    
    /**
     * @dev Allows the recipient to withdraw available funds from a stream
     * @param streamId The ID of the stream to withdraw from
     * @param amount The amount to withdraw
     */
    function withdrawFromStream(uint256 streamId, uint256 amount) external {
        Stream storage stream = streams[streamId];
        require(stream.isActive, "Stream is not active");
        require(msg.sender == stream.recipient, "Only recipient can withdraw");
        
        uint256 available = balanceOf(streamId);
        require(amount > 0 && amount <= available, "Invalid withdrawal amount");
        
        stream.withdrawnAmount += amount;
        
        if (block.timestamp >= stream.stopTime && stream.withdrawnAmount >= stream.depositAmount) {
            stream.isActive = false;
        }
        
        payable(msg.sender).transfer(amount);
        
        emit StreamWithdrawn(streamId, msg.sender, amount);
    }
    
    /**
     * @dev Cancels an active stream and returns unstreamed funds to sender
     * @param streamId The ID of the stream to cancel
     */
    function cancelStream(uint256 streamId) external {
        Stream storage stream = streams[streamId];
        require(stream.isActive, "Stream is not active");
        require(
            msg.sender == stream.sender || msg.sender == stream.recipient,
            "Only sender or recipient can cancel"
        );
        
        uint256 recipientBalance = balanceOf(streamId);
        uint256 senderBalance = stream.depositAmount - stream.withdrawnAmount - recipientBalance;
        
        stream.isActive = false;
        
        if (recipientBalance > 0) {
            stream.withdrawnAmount += recipientBalance;
            payable(stream.recipient).transfer(recipientBalance);
        }
        
        if (senderBalance > 0) {
            payable(stream.sender).transfer(senderBalance);
        }
        
        emit StreamCancelled(streamId, stream.sender, stream.recipient, senderBalance, recipientBalance);
    }
    
    /**
     * @dev Returns stream details
     * @param streamId The ID of the stream
     */
    function getStream(uint256 streamId) external view returns (
        address sender,
        address recipient,
        uint256 depositAmount,
        uint256 startTime,
        uint256 stopTime,
        uint256 withdrawnAmount,
        bool isActive
    ) {
        Stream memory stream = streams[streamId];
        return (
            stream.sender,
            stream.recipient,
            stream.depositAmount,
            stream.startTime,
            stream.stopTime,
            stream.withdrawnAmount,
            stream.isActive
        );
    }
}
