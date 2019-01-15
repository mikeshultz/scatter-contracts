pragma solidity >0.4.0 <0.6.0;

library Structures {
    
    struct Validation {
        int bidId;
        uint when;
        address payable validator;
        bool isValid;
        bool paid;
    }

    struct Bid {
        address payable bidder;
        bytes32 fileHash;
        int64 fileSize;
        uint bidAmount;
        uint validationPool;
        uint duration;
        uint accepted;
        bool paid;
        address payable hoster;
        uint pinned;
        int16 minValidations;  // Also, kind of, minimum majority (e.g. win by X)
        //Validation[] validations;
    }

}