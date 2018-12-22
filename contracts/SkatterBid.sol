pragma solidity ^0.4.25;

import './SafeMath.sol';
import './Env.sol';
import './SkatterRewards.sol';

contract SkatterBid {
    using SafeMath for uint;
    
    struct Validation {
        int64 bidId;
        uint when;
        address validator;
        bool isValid;
    }

    struct Bid {
        address bidder;
        bytes32 fileHash;
        int64 fileSize;
        uint bidAmount;
        uint validationPool;
        uint duration;
        uint accepted;
        address hoster;
        uint pinned;
        bool paid;
        int16 minValidations;
        Validation[] validations;
    }

    event BidSuccessful(
        int64 indexed bidId,
        address indexed bidder,
        uint indexed bidValue,
        bytes32 fileHash
    );
    event BidInvalid(bytes32 indexed fileHash, string reason);
    event BidTooLow(bytes32 indexed fileHash);
    event Accepted(int64 indexed bidId, address indexed hoster);
    event AcceptWait(uint waitLeft);
    event Pinned(int64 indexed bidId, address indexed hoster, bytes32 fileHash);
    event NotAcceptedByPinner(int64 indexed bidId, address indexed hoster);
    event DispurseFailed(int64 indexed bidId, address indexed sender);
    event ValidationOcurred(int64 indexed bidId, address indexed validator, bool indexed isValid);

    address owner;
    Env env;

    int64 bidCount;
    mapping(int64 => Bid) bids;
    uint remainderFunds;

    bytes32 constant EMPTY_IPFS_FILE = 0xbfccda787baba32b59c78450ac3d20b633360b43992c77289f9ed46d843561e6;

    modifier ownerOnly() { require(msg.sender == owner, "denied"); _; }
    modifier notBanned() { require(!env.isBanned(msg.sender), "banned"); _; }

    constructor(address _env) public
    {
        owner = msg.sender;
        env = Env(_env);
    }

    /**
     * Utility
     */

    function isBidOpen(int64 bidId) public view
    returns (bool)
    {
        uint acceptWait = env.getuint("acceptHoldDuration");
        return (
            bids[bidId].fileHash != bytes32(0)
            && bids[bidId].pinned == 0
            && (bids[bidId].accepted == 0 || now - uint(bids[bidId].accepted) >= acceptWait)
            && bids[bidId].bidder != msg.sender
        );
    }

    function validationSway(int64 bidId) public view returns (uint)
    {
        uint total = bids[bidId].validations.length;
        uint sway = 0;
        for (uint i=0; i<total; i++)
        {
            if (bids[bidId].validations[i].isValid)
            {
                sway += 1;
            }
            else
            {
                sway -= 1;
            }
        }
        return sway;
    }

    function satisfied(int64 bidId) public view returns (bool)
    {
        uint total = bids[bidId].validations.length;
        if (total < uint(bids[bidId].minValidations))
        {
            return false;
        }

        uint sway = validationSway(bidId);

        if (sway == 0) // No ties
        {
            return false;
        }
        
        uint majoritySway = uint(bids[bidId].minValidations) / sway;

        return(uint(-1) <= majoritySway && majoritySway <= uint(1)); // Must be a simple majority or better
    }

    function addValidation(int64 bidId, bool isValid)
    internal
    {
        require(bids[bidId].pinned > 0, "not open");

        Validation memory validation = Validation(
            bidId,
            now,
            msg.sender,
            isValid
        );

        bids[bidId].validations.push(validation);

        emit ValidationOcurred(bidId, msg.sender, isValid);
    }

    /**
     * Readers
     */

    function getJob() public view returns (int64, bytes32, int64)
    {
        // TODO: Look into a queue library, maybe?
        // TODO: Test this with thousands(or more) bids
        for (int64 i=0; i<bidCount; i++)
        {
            if (isBidOpen(i))
            {
                return (i, bids[i].fileHash, bids[i].fileSize);
            }
        }
        return (-1, 0, 0);
    }

    function getValidation(int64 bidId, uint idx) public view
    returns (int64, uint, address, bool)
    {
        Validation memory v = bids[bidId].validations[idx];
        return (
            v.bidId,
            v.when,
            v.validator,
            v.isValid
        );
    }

    function getValidationCount(int64 bidId)
    public view returns (uint)
    {
        return bids[bidId].validations.length;
    }

    /**
     * Writers
     */

    function setOwner(address newOwner)
    public
    ownerOnly
    {
        require(newOwner != address(0), "invalid address");
        owner = newOwner;
    }

    function bid(
        bytes32 fileHash,
        int64 fileSize,
        uint durationSeconds,
        uint bidValue,
        uint validationPool
    )
    public notBanned
    payable
    returns (bool)
    {
        // Use the minimum validations default from the Env contract
        uint minValid = env.getuint("defaultMinValidations");
        return bid(fileHash, fileSize, durationSeconds, bidValue, validationPool,int16(minValid));
    }

    function bid(
        bytes32 fileHash,
        int64 fileSize,
        uint durationSeconds,
        uint bidValue,
        uint validationPool,
        int16 minValidations
    )
    public notBanned
    payable
    returns (bool)
    {

        // Input Validation
        if (fileHash == bytes32(0) || fileSize < 1)
        {
            emit BidInvalid(fileHash, "invalid file");
            return false;
        }

        if (fileHash == EMPTY_IPFS_FILE) // IPFS hash of a zero-length file
        {
            emit BidInvalid(fileHash, "empty file");
            return false;
        }

        uint minDuration = env.getuint('minDuration');
        if (durationSeconds < minDuration) // IPFS hash of a zero-length file
        {
            emit BidInvalid(fileHash, "duration low");
            return false;
        }

        if (bidValue < 1)
        {
            emit BidInvalid(fileHash, "bid zero");
            return false;
        }

        if (bidValue < env.getuint("minBid"))
        {
            emit BidTooLow(fileHash);
            return false;
        }

        // Needs to be more than 0 and min divisible by participants
        if (validationPool < uint(minValidations))
        {
            emit BidInvalid(fileHash, "zero pool");
            return false;
        }

        int64 bidId = bidCount;

        // Store the bid
        bids[bidId].bidder = msg.sender;
        bids[bidId].fileHash = fileHash;
        bids[bidId].fileSize = fileSize;
        bids[bidId].bidAmount = bidValue;
        bids[bidId].validationPool = validationPool;
        bids[bidId].minValidations = minValidations;
        bids[bidId].duration = durationSeconds;

        emit BidSuccessful(bidId, msg.sender, bidValue, fileHash);

        bidCount++;

        return true;
    }

    function accept(int64 bidId) public notBanned
    returns (bool)
    {

        uint acceptWait = env.getuint("acceptHoldDuration");
        if (now - bids[bidId].accepted < acceptWait)
        {
            emit AcceptWait(now - bids[bidId].accepted);
            return false;
        }

        // Set the accepted timer
        bids[bidId].accepted = now;
        bids[bidId].hoster = msg.sender;

        emit Accepted(bidId, msg.sender);

        return true;
    }

    function pinned(int64 bidId) public notBanned
    returns (bool)
    {
        require(bids[bidId].pinned == 0, "already pinned");

        if (msg.sender != bids[bidId].hoster)
        {
            emit NotAcceptedByPinner(bidId, bids[bidId].hoster);
            return false;
        }

        bids[bidId].pinned = now;

        emit Pinned(bidId, msg.sender, bids[bidId].fileHash);

        return true;
    }

    function validate(int64 bidId)
    public notBanned
    {
        addValidation(bidId, true);
    }

    function invalidate(int64 bidId)
    public notBanned
    {
        addValidation(bidId, false);
    }

    function dispurse(int64 bidId) public notBanned
    {
        if (!satisfied(bidId))
        {
            emit DispurseFailed(bidId, msg.sender);
            return;
        }

        bids[bidId].paid = true;

        uint split;
        uint remainder;
        (split, remainder) = SkatterRewards.getSplitAndRemainder(
            bids[bidId].validationPool,
            bids[bidId].validations.length
        );

        for (uint i=0; i<bids[bidId].validations.length; i++)
        {
            bids[bidId].validations[i].validator.transfer(split);
        }

        bids[bidId].hoster.transfer(bids[bidId].bidAmount);
        
        if (remainder > 0)
        {
            remainderFunds += remainder;
        }

    }

}