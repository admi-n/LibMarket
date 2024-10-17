
//   __        __  __        __       __                      __                   __     
//  |  \      |  \|  \      |  \     /  \                    |  \                 |  \    
//  | $$       \$$| $$____  | $$\   /  $$  ______    ______  | $$   __   ______  _| $$_   
//  | $$      |  \| $$    \ | $$$\ /  $$$ |      \  /      \ | $$  /  \ /      \|   $$ \  
//  | $$      | $$| $$$$$$$\| $$$$\  $$$$  \$$$$$$\|  $$$$$$\| $$_/  $$|  $$$$$$\\$$$$$$  
//  | $$      | $$| $$  | $$| $$\$$ $$ $$ /      $$| $$   \$$| $$   $$ | $$    $$ | $$ __ 
//  | $$_____ | $$| $$__/ $$| $$ \$$$| $$|  $$$$$$$| $$      | $$$$$$\ | $$$$$$$$ | $$|  \
//  | $$     \| $$| $$    $$| $$  \$ | $$ \$$    $$| $$      | $$  \$$\ \$$     \  \$$  $$
//   \$$$$$$$$ \$$ \$$$$$$$  \$$      \$$  \$$$$$$$ \$$       \$$   \$$  \$$$$$$$   \$$$$ 
//
                                                


// SPDX-License-Identifier: LibMarket
pragma solidity ^0.8.20;

abstract contract Ownable2Step {
    address private _owner;
    address private _pendingOwner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function pendingOwner() public view returns (address) {
        return _pendingOwner;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(_owner, newOwner);
    }

    function acceptOwnership() public {
        require(msg.sender == _pendingOwner, "Ownable: caller is not the new owner");
        emit OwnershipTransferred(_owner, _pendingOwner);
        _owner = _pendingOwner;
        _pendingOwner = address(0);
    }
}

contract Pausable is Ownable2Step {
    bool public paused;

    event Paused(address account);
    event Unpaused(address account);

    constructor() {
        paused = false;
    }

    modifier whenNotPaused() {
        require(!paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "Pausable: not paused");
        _;
    }

    function pause() public onlyOwner whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyOwner whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }
}


library EconomyLib {
    struct Trade {
        address payable seller;
        address payable buyer;
        uint amount;
        TradeStatus status;
        bytes32 hashLock;
        uint256 timelock;
    }

    enum TradeStatus { Pending, Locked, OrderInProgress, Complete, Cancelled }
}


// library EconomyLib {
//     struct Trade {
//         address payable seller;
//         address payable buyer;
//         uint amount;
//         TradeStatus status;
//         bytes32 hashLock;
//         uint256 timelock;
//     }

//     event RewardDistributed(address indexed seller, address indexed buyer, uint amount);

//     struct Economy {
//         uint totalFees;  // 总手续费
//         uint rewardPool;  // 激励池
//     }

//     enum TradeStatus { Pending, Locked, OrderInProgress, Complete, Cancelled }

//     function calculateFee(uint amount) internal pure returns (uint) {
//         return (amount * 5) / 1000;  // 0.5% 手续费
//     }

//     function addToRewardPool(Economy storage economy, uint fee) internal {
//         economy.rewardPool += fee;
//     }

//     function distributeRewards(Economy storage economy, uint tradeCounter, mapping(uint => Trade) storage trades) internal {
//         require(tradeCounter > 0, "No trades to distribute rewards");
//         uint rewardPerTrade = economy.rewardPool / tradeCounter;

//         for (uint i = 0; i < tradeCounter; i++) {
//             if (trades[i].status == TradeStatus.Complete) {
//                 uint rewardShare = rewardPerTrade / 2;
//                 trades[i].seller.transfer(rewardShare);
//                 trades[i].buyer.transfer(rewardShare);


//                 emit RewardDistributed(trades[i].seller, trades[i].buyer, rewardShare);

//             }
//         }

//         economy.rewardPool = 0;  // 清空激励池
//     }
// }

contract HashLock is Pausable {
    struct Lock {
        uint256 amount;
        bytes32 hashLock;
        uint256 timelock;
        address payable sender;
        address payable receiver;
        bool withdrawn;
        bool refunded;
        bytes32 preimage;
    }

    mapping(bytes32 => Lock) public locks;

    event Locked(bytes32 indexed lockId, address indexed sender, address indexed receiver, uint256 amount, bytes32 hashLock, uint256 timelock);
    event Withdrawn(bytes32 indexed lockId, bytes32 preimage);
    event Refunded(bytes32 indexed lockId);

    function lock(bytes32 _hashLock, uint256 _timelock, address payable _receiver) internal whenNotPaused returns (bytes32 lockId) {
        require(msg.value > 0, "Amount must be greater than 0");
        require(_timelock > block.timestamp, "Timelock must be in the future");

        lockId = keccak256(abi.encodePacked(msg.sender, _receiver, msg.value, _hashLock, _timelock));
        require(locks[lockId].sender == address(0), "Lock already exists");

        locks[lockId] = Lock({
            amount: msg.value,
            hashLock: _hashLock,
            timelock: _timelock,
            sender: payable(msg.sender),
            receiver: _receiver,
            withdrawn: false,
            refunded: false,
            preimage: bytes32(0)
        });

        emit Locked(lockId, msg.sender, _receiver, msg.value, _hashLock, _timelock);
    }

    function withdraw(bytes32 _lockId, bytes32 _preimage) external whenNotPaused {
        Lock storage lock = locks[_lockId];

        require(lock.amount > 0, "Lock does not exist");
        require(lock.receiver == msg.sender, "Not the receiver");
        require(!lock.withdrawn, "Already withdrawn");
        require(!lock.refunded, "Already refunded");
        require(keccak256(abi.encodePacked(_preimage)) == lock.hashLock, "Invalid preimage");

        lock.withdrawn = true;
        lock.preimage = _preimage;
        lock.receiver.transfer(lock.amount);

        emit Withdrawn(_lockId, _preimage);
    }

    function refund(bytes32 _lockId) external whenNotPaused {
        Lock storage lock = locks[_lockId];

        require(lock.amount > 0, "Lock does not exist");
        require(lock.sender == msg.sender, "Not the sender");
        require(!lock.withdrawn, "Already withdrawn");
        require(!lock.refunded, "Already refunded");
        require(block.timestamp >= lock.timelock, "Timelock not yet passed");

        lock.refunded = true;
        lock.sender.transfer(lock.amount);

        emit Refunded(_lockId);
    }
}

// 主要合约
contract C2CPlatform is HashLock {
    //using EconomyLib for EconomyLib.Economy;
    using EconomyLib for mapping(uint => EconomyLib.Trade);

    //EconomyLib.Economy private economy;

    // 交易ID到交易详情的映射
    mapping(uint => EconomyLib.Trade) public trades;
    uint public tradeCounter;

    event TradeCreated(uint tradeId, address seller, address buyer, uint amount, bytes32 hashLock, uint256 timelock);
    event TradeLocked(uint tradeId);
    event TradeConfirmed(uint tradeId);
    event TradeCancelled(uint tradeId);
    event FeeCollected(uint tradeId, uint fee);
    event LogPreimage(bytes32 preimage);

    // 创建新交易
    function createTrade(address payable _seller, bytes32 _hashLock, uint256 _timelock) external payable whenNotPaused {
        require(msg.value > 0, "Amount must be greater than 0");
        require(_timelock > block.timestamp, "Timelock must be in the future");

        bytes32 lockId = lock(_hashLock, _timelock, _seller);

        trades[tradeCounter] = EconomyLib.Trade({
            seller: _seller,
            buyer: payable(msg.sender),
            amount: msg.value,  // 不再扣除手续费，直接全额存入
            status: EconomyLib.TradeStatus.Pending,
            hashLock: _hashLock,
            timelock: _timelock
    });

    emit TradeCreated(tradeCounter, _seller, msg.sender, msg.value, _hashLock, _timelock);
    tradeCounter++;
}
    // function createTrade(address payable _seller, bytes32 _hashLock, uint256 _timelock) external payable whenNotPaused {
    //     require(msg.value > 0, "Amount must be greater than 0");
    //     require(_timelock > block.timestamp, "Timelock must be in the future");

    //     bytes32 lockId = lock(_hashLock, _timelock, _seller);

    //     uint fee = EconomyLib.calculateFee(msg.value);  // 调用库中的calculateFee函数
    //     economy.addToRewardPool(fee);

    //     trades[tradeCounter] = EconomyLib.Trade({
    //         seller: _seller,
    //         buyer: payable(msg.sender),
    //         amount: msg.value - fee,
    //         status: EconomyLib.TradeStatus.Pending,
    //         hashLock: _hashLock,
    //         timelock: _timelock
    //     });

    //     emit FeeCollected(tradeCounter, fee);
    //     emit TradeCreated(tradeCounter, _seller, msg.sender, msg.value - fee, _hashLock, _timelock);
    //     tradeCounter++;
    // }

    // 锁定资金
    function lockFunds(uint _tradeId) external whenNotPaused {
        EconomyLib.Trade storage trade = trades[_tradeId];
        require(msg.sender == trade.buyer, "Only buyer can lock funds");
        require(trade.status == EconomyLib.TradeStatus.Pending, "Trade is not in pending state");

        trade.status = EconomyLib.TradeStatus.Locked;
        emit TradeLocked(_tradeId);
    }

    // 卖家确认发货
    function confirmShipment(uint _tradeId) external whenNotPaused {
        EconomyLib.Trade storage trade = trades[_tradeId];
        require(msg.sender == trade.seller, "Only seller can confirm shipment");
        require(trade.status == EconomyLib.TradeStatus.Locked, "Funds are not locked");

        trade.status = EconomyLib.TradeStatus.OrderInProgress;
        emit TradeConfirmed(_tradeId);
    }

    // 买家确认收货
    function confirmReceipt(uint _tradeId, bytes32 _preimage) external whenNotPaused {
        EconomyLib.Trade storage trade = trades[_tradeId];
        require(msg.sender == trade.buyer, "Only buyer can confirm receipt");
        require(trade.status == EconomyLib.TradeStatus.OrderInProgress, "Funds are not in order progress state");
        require(keccak256(abi.encodePacked(_preimage)) == trade.hashLock, "Invalid preimage");

        trade.status = EconomyLib.TradeStatus.Complete;
        trade.seller.transfer(trade.amount);
        emit TradeConfirmed(_tradeId);

        emit LogPreimage(_preimage);
    }

    // 取消交易并退还资金
    function cancelTrade(uint _tradeId) external whenNotPaused {
        EconomyLib.Trade storage trade = trades[_tradeId];
        require(msg.sender == trade.buyer, "Only buyer can cancel trade");
        require(trade.status == EconomyLib.TradeStatus.Pending || trade.status == EconomyLib.TradeStatus.Locked, "Cannot cancel trade in current state");

        if (trade.status == EconomyLib.TradeStatus.Locked) {
            trade.status = EconomyLib.TradeStatus.Cancelled;
            trade.buyer.transfer(trade.amount);
        } else if (trade.status == EconomyLib.TradeStatus.Pending) {
            trade.status = EconomyLib.TradeStatus.Cancelled;
        }

        emit TradeCancelled(_tradeId);
    }

    // 每周分配激励池
    // function distributeWeeklyRewards() external onlyOwner whenNotPaused {
    //     economy.distributeRewards(tradeCounter, trades);
    // }
}



// 用于后期更新(暂定)
contract Create2Factory {
    event Deploy(address add);

    function deploy(uint _salt) external {
        C2CPlatform _contract = new C2CPlatform{salt: bytes32(_salt)}();
        emit Deploy(address(_contract));
    }

    function getAddress(bytes memory bytecode, uint _salt) public view returns(address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
        return address(uint160(uint(hash)));
    }

    function getBytecode(address _owner) public pure returns (bytes memory){
        bytes memory bytecode = type(C2CPlatform).creationCode;
        return abi.encodePacked(bytecode, abi.encode(_owner));
    }
}