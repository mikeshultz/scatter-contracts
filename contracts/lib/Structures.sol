pragma solidity >0.4.0 <0.6.0;


library Structures {

    struct Defense {
        int bidID;
        int challengeID;
        int defenseID;
        uint when;
        address payable pinner;
        bytes32 uniqueHash;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    
    struct Challenge {
        int bidID;
        int challengeID;
        uint when;
        address payable challenger;
        int[] defenses;
    }
    
    struct Stake {
        int bidID;
        uint when;
        uint value;
        address payable staker;
    }

    struct Bid {
        address payable bidder;
        bytes32 fileHash;
        int64 fileSize;
        uint bidAmount;
        uint duration;
        int8 requiredPinners;
        bool paid;
        address payable[] pinners;
        int[] challenges;
    }

}
