pragma solidity ^0.5.2;

import "../lib/Owned.sol";
import "../lib/Structures.sol";
import "../interface/IBidStore.sol";


contract BidStore is Owned {  // Also is IBidStore, but solc doesn't like that ref

    int public bidCount;
    mapping(int => Structures.Bid) private bids;
    address public scatterBidAddress;

    modifier scatterBidOnly() { require(msg.sender == scatterBidAddress, "not allowed"); _; }

    constructor(address _scatterBid) public {
        scatterBidAddress = _scatterBid;
    }

    /**
     * BidStore setter interface
     */

    function addValidation(int bidId, address payable _validator, bool _isValid)
    external scatterBidOnly returns (bool)
    {
        if (bids[bidId].bidder == address(0))
        {
            return false;
        }

        Structures.Validation memory vlad = Structures.Validation(
            bidId,      // bidId
            now,        // when
            _validator, // validator
            _isValid,   // isvalid
            false       // paid
        );

        bids[bidId].validations.push(vlad);

        return true;
    }

    function setValidatorPaid(int bidId, uint idx) external scatterBidOnly returns (bool)
    {
        if (bids[bidId].validations[idx].when == 0)
        {
            return false;
        }

        bids[bidId].validations[idx].paid = true;
        return true;
    }

    function setHoster(int bidId, address payable _hoster) external scatterBidOnly returns (bool)
    {
        if (bids[bidId].bidder == address(0))
        {
            return false;
        }

        bids[bidId].hoster = _hoster;
        return true;
    }

    function setHosterPaid(int bidId) external scatterBidOnly returns (bool)
    {
        if (bids[bidId].bidder == address(0) || bids[bidId].hoster == address(0))
        {
            return false;
        }

        bids[bidId].paid = true;
        return true;
    }

    function setAcceptNow(int bidId, address payable hoster) external returns (bool)
    {
        if (bids[bidId].bidder == address(0))
        {
            return false;
        }

        bids[bidId].accepted = now;
        bids[bidId].hoster = hoster;
        return true;
    }


    function setPinned(int bidId, address payable hoster) external returns (bool)
    {
        if (bids[bidId].bidder == address(0))
        {
            return false;
        }

        bids[bidId].pinned = now;

        if (bids[bidId].hoster != hoster)
        {
            bids[bidId].hoster = hoster;
        }

        return true;
    }

    function addBid(address payable _sender, bytes32 fileHash, int64 fileSize, uint bidValue, 
                    uint validationPool, int16 minValidations, uint durationSeconds)
    external scatterBidOnly returns (int)
    {
        int bidId = bidCount;

        bids[bidId].bidder = _sender;
        bids[bidId].fileHash = fileHash;
        bids[bidId].fileSize = fileSize;
        bids[bidId].bidAmount = bidValue;
        bids[bidId].validationPool = validationPool;
        bids[bidId].duration = durationSeconds;
        bids[bidId].minValidations = minValidations;

        bidCount += 1;

        return bidId;
    }

    /**
     * BidStore getter interface
     */

    function isPinned(int bidId) external view returns (bool)
    {
        return (bids[bidId].pinned > 0);
    }

    function getPinned(int bidId) external view returns (uint)
    {
        return bids[bidId].pinned;
    }

    function getBidder(int bidId) external view returns (address payable)
    {
        return bids[bidId].bidder;
    }

    function getAccepted(int bidId) external view returns (uint)
    {
        return bids[bidId].accepted;
    }

    function getHoster(int bidId) external view returns (address)
    {
        return bids[bidId].hoster;
    }

    function getFileHash(int bidId) external view returns (bytes32)
    {
        return bids[bidId].fileHash;
    }

    function getFileSize(int bidId) external view returns (int64)
    {
        return bids[bidId].fileSize;
    }

    function getValidationPool(int bidId) external view returns (uint)
    {
        return bids[bidId].validationPool;
    }

    function getBidAmount(int bidId) external view returns (uint)
    {
        return bids[bidId].bidAmount;
    }

    function getValidationCount(int bidId) external view returns (uint)
    {
        return bids[bidId].validations.length;
    }

    function getValidatorIndex(int bidId, address payable _validator) external view returns (uint)
    {
        if (bids[bidId].bidder == address(0))
        {
            return uint(-1);
        }

        for (uint i = 0; i < bids[bidId].validations.length; i++)
        {
            if (bids[bidId].validations[i].validator == _validator)
            {
                return i;
            }
        }

        return uint(-1);
    }
    
    function getValidator(int bidId, uint idx) external view returns (address payable)
    {
        return bids[bidId].validations[idx].validator;
    }

    function getValidation(int bidId, uint idx) external view returns (
        uint,       // when
        address,    // validator
        bool,       // isValid
        bool        // paid
    )
    {
        return (
            bids[bidId].validations[idx].when,
            bids[bidId].validations[idx].validator,
            bids[bidId].validations[idx].isValid,
            bids[bidId].validations[idx].paid
        );
    }

    function getValidationIsValid(int bidId, uint idx) external view returns (bool)
    {
        return bids[bidId].validations[idx].isValid;
    }

    function bidExists(int bidId) external view returns (bool)
    {
        if (bids[bidId].bidder == address(0))
        {
            return false;
        }
        return true;
    }

    function getBid(int bidId) external view returns (
        address,
        bytes32,
        int,
        uint,
        uint,
        uint,
        int16
    )
    {
        return(
            bids[bidId].bidder,
            bids[bidId].fileHash,
            bids[bidId].fileSize,
            bids[bidId].bidAmount,
            bids[bidId].validationPool,
            bids[bidId].duration,
            bids[bidId].minValidations
        );
    }

    /**
     * Admin interface
     */

    function setScatterBid(address _newAddress) public ownerOnly
    {
        assert(_newAddress != address(0));
        scatterBidAddress = _newAddress;
    }

    function setBidCount(int _bidCount) public ownerOnly
    {
        bidCount = _bidCount;
    }

}