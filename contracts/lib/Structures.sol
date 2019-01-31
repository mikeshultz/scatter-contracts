pragma solidity >0.4.0 <0.6.0;


library Structures {

    struct Defense {
        uint bidID;
        uint challengeID;
        uint defenseID;
        uint8 nonce;
        uint when;
        address payable pinner;
        bytes16 halfHashA;
        bytes16 halfHashB;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    
    struct Challenge {
        uint bidID;
        uint challengeID;
        uint when;
        address payable challenger;
        bool defended;
        uint[] defenses;
    }
    
    struct Stake {
        uint bidID;
        uint8 nonce;
        uint when;
        uint value;
        address payable staker;
    }

    struct Bid {
        address payable bidder;
        uint when;
        bytes32 fileHash;
        uint64 fileSize;
        uint bidAmount;
        uint duration;
        uint8 requiredPinners;
        bool paid;
        address payable[] pinners;
        uint[] challenges;
    }

}
