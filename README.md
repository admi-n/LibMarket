# Early stage construction........



# LibMarket

Aims to build an open e-commerce platform based on Web3, with equality, reasonable distribution, free communication and pricing, and adopting a CtoC model. You can sell paintings (physical), flowers, concert tickets, clothes and any other items here!!













-----------------------------

ing



Sample Contract Monomer Model...

```mermaid
flowchart TD
    %% Users interacting with the system
    Buyer((Buyer)) -->|Create Trade| C2CPlatform
    Seller((Seller)) -->|Lock Funds| C2CPlatform

    %% Core contract logic
    C2CPlatform -->|Pending| TradeStatePending{{Pending State}}
    C2CPlatform -->|Locked| TradeStateLocked{{Locked State}}
    C2CPlatform -->|Shipment Confirmed| TradeInProgress{{In Progress}}
    C2CPlatform -->|Complete| TradeComplete{{Complete State}}

    %% Functions associated with the contract
    subgraph Contract Functions
        C2CPlatform --> CreateTrade
        C2CPlatform --> LockFunds
        C2CPlatform --> ConfirmShipment
        C2CPlatform --> ConfirmReceipt
        C2CPlatform --> CancelTrade
    end

    %% HashLock mechanism
    subgraph HashLock Mechanism
        HashLock --> LockFundsProcess((Lock Funds))
        HashLock --> WithdrawFundsProcess((Withdraw Funds))
        HashLock --> RefundProcess((Refund))
    end

    %% Ownership and Pause Control
    subgraph Inherited Contracts
        Ownable2Step --> C2CPlatform
        Pausable --> C2CPlatform
    end
```

