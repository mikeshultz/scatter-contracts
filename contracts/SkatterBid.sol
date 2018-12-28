pragma solidity ^0.5.2;

import './SafeMath.sol';
import './Env.sol';
import './SkatterRewards.sol';

contract SkatterBid {
    using SafeMath for uint;
    
    struct Validation {
        int64 bidId;
        uint when;
        address payable validator;
        bool isValid;
        bool paid;
    }

    struct Bid {
        address bidder;
        bytes32 fileHash;
        int64 fileSize;
        uint bidAmount;
        uint validationPool;
        uint duration;
        uint accepted;
        bool paid;
        address payable hoster;
        uint pinned;
        int16 minValidations;
        Validation[] validations;
    }

    event BidSuccessful(
        int64 indexed bidId,
        address indexed bidder,
        uint indexed bidValue,
        uint validationPool,
        bytes32 fileHash,
        int64 fileSize
    );
    event BidInvalid(bytes32 indexed fileHash, string reason);
    event BidTooLow(bytes32 indexed fileHash);
    event Accepted(int64 indexed bidId, address indexed hoster);
    event AcceptWait(uint waitLeft);
    event Pinned(int64 indexed bidId, address indexed hoster, bytes32 fileHash);
    event NotAcceptedByPinner(int64 indexed bidId, address indexed hoster);
    event WithdrawFailed(int64 indexed bidId, address indexed sender, string reason);
    event WithdrawDuplicate(int64 indexed bidId, address indexed sender);
    event WithdrawHoster(int64 indexed bidId, address indexed hoster);
    event WithdrawValidator(int64 indexed bidId, address indexed validator);
    event ValidationOcurred(int64 indexed bidId, address indexed validator, bool indexed isValid);
    event GeneralError(string why);

    address public owner;
    Env public env;

    int64 public bidCount;
    mapping(int64 => Bid) bids;
    uint public remainderFunds;

    bytes32 constant EMPTY_IPFS_FILE = 0xbfccda787baba32b59c78450ac3d20b633360b43992c77289f9ed46d843561e6;
    bytes32 constant ENV_ACCEPT_HOLD_DURATION = keccak256("acceptHoldDuration");
    bytes32 constant ENV_DEFAULT_MIN_VALIDATIONS = keccak256("defaultMinValidations");
    bytes32 constant ENV_MIN_DURATION = keccak256("minDuration");
    bytes32 constant ENV_MIN_BID = keccak256("minBid");

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
        uint acceptWait = env.getuint(ENV_ACCEPT_HOLD_DURATION);
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
            isValid,
            false
        );

        bids[bidId].validations.push(validation);

        emit ValidationOcurred(bidId, msg.sender, isValid);
    }

    /**
     * Readers
     */

    function getBid(int64 bidId) public view returns (
        address,
        bytes32,
        int64,
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
    returns (int64, uint, address, bool, bool)
    {
        Validation memory v = bids[bidId].validations[idx];
        return (
            v.bidId,
            v.when,
            v.validator,
            v.isValid,
            v.paid
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
        uint minValid = env.getuint(ENV_DEFAULT_MIN_VALIDATIONS);
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

        bidCount++;

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

        uint minDuration = env.getuint(ENV_MIN_DURATION);
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

        if (bidValue < env.getuint(ENV_MIN_BID))
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

        emit BidSuccessful(bidId, msg.sender, bidValue, validationPool, fileHash, fileSize);

        return true;
    }

    function accept(int64 bidId) public notBanned
    returns (bool)
    {

        uint acceptWait = env.getuint(ENV_ACCEPT_HOLD_DURATION);
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

    function validatorIndex(int64 bidId, address validator) public view returns (uint)
    {

        if (bids[bidId].validations.length < 1)
        {
            return uint(-1);
        }

        for (uint i=0; i<bids[bidId].validations.length; i++)
        {
            if (validator == bids[bidId].validations[i].validator)
            {
                return i;
            }
        }

        return uint(-1);

    }

    function withdraw(int64 bidId) public notBanned
    {
        uint validatorIdx = validatorIndex(bidId, msg.sender);

        // Withdraw for a validator
        if (validatorIdx > uint(-1))
        {
            if (bids[bidId].validations[validatorIdx].paid)
            {
                emit WithdrawFailed(bidId, msg.sender, "already paid");
                return;
            }

            if (bids[bidId].validationPool < 1)
            {
                emit WithdrawFailed(bidId, msg.sender, "nothing to withdraw");
                return;
            }

            uint split;
            uint remainder;
            (split, remainder) = SkatterRewards.getSplitAndRemainder(
                bids[bidId].validationPool,
                bids[bidId].validations.length
            );

            assert(split > 0);
            assert(
                (bids[bidId].validations.length == 1 && split == bids[bidId].validationPool)
                || (bids[bidId].validations.length > 1 && split < bids[bidId].validationPool)
            );

            bids[bidId].validations[validatorIdx].paid = true;

            msg.sender.transfer(split);

            if (remainder > 0)
            {
                remainderFunds += remainder;
            }

            emit WithdrawValidator(bidId, msg.sender);
        }
        // Or a hoster
        else if (bids[bidId].hoster == msg.sender)
        {
            assert(bids[bidId].bidAmount > 0);
            assert(address(this).balance > 0);

            if (bids[bidId].paid)
            {
                emit GeneralError("already paid");
                return;
            }

            bids[bidId].paid = true;
            bids[bidId].hoster.transfer(bids[bidId].bidAmount);

            emit WithdrawHoster(bidId, msg.sender);
        }
        // This user shouldn't be submitting
        else
        {
            emit WithdrawFailed(bidId, msg.sender, "invalid widthrawer");
        }

    }

}