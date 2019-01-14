pragma solidity ^0.5.2;

import "./interface/IRouter.sol";
import "./interface/IScatter.sol";

import "./lib/Owned.sol";
import "./lib/SafeMath.sol";
import "./lib/Structures.sol";
import "./lib/Rewards.sol";

import "./storage/Env.sol";
import "./storage/BidStore.sol";


contract Scatter is Owned {  /// interface: IScatter
    using SafeMath for uint;

    event BidSuccessful(
        int indexed bidId,
        address indexed bidder,
        uint indexed bidValue,
        uint validationPool,
        bytes32 fileHash,
        int fileSize
    );
    event BidInvalid(bytes32 indexed fileHash, string reason);
    event BidTooLow(bytes32 indexed fileHash);
    event Accepted(int indexed bidId, address indexed hoster);
    event AcceptWait(uint waitLeft);
    event Pinned(int indexed bidId, address indexed hoster, bytes32 fileHash);
    event NotAcceptedByPinner(int indexed bidId, address indexed hoster);
    event WithdrawFailed(address indexed sender, string reason);
    event Withdraw(uint indexed value, address indexed hoster);
    event Paid(int indexed bidId, uint indexed value, address indexed validator);
    event ValidationOcurred(int indexed bidId, address indexed validator, bool indexed isValid);
    event GeneralError(string why);

    Env public env;
    IBidStore public bidStore;

    int public bidCount;
    mapping(int => Structures.Bid) private bids;
    mapping(address => uint) private balanceSheet;
    uint public remainderFunds;

    // solhint-disable-next-line max-line-length
    bytes32 private constant EMPTY_IPFS_FILE = 0xbfccda787baba32b59c78450ac3d20b633360b43992c77289f9ed46d843561e6;
    bytes32 private constant ENV_ACCEPT_HOLD_DURATION = keccak256("acceptHoldDuration");
    bytes32 private constant ENV_DEFAULT_MIN_VALIDATIONS = keccak256("defaultMinValidations");
    bytes32 private constant ENV_MIN_DURATION = keccak256("minDuration");
    bytes32 private constant ENV_MIN_BID = keccak256("minBid");

    modifier notBanned() { require(!env.isBanned(msg.sender), "banned"); _; }
    modifier notLocked() { require(!env.isBanned(msg.sender), "banned"); _; }

    constructor(address _env, address _bidStore) public
    {
        owner = msg.sender;
        env = Env(_env);
        bidStore = IBidStore(_bidStore);
    }

    /**
     * Utility
     */

    function isBidOpenForPin(int bidId, address _hoster) public view
    returns (bool)
    {
        uint acceptWait = env.getuint(ENV_ACCEPT_HOLD_DURATION);
        bytes32 fileHash = bidStore.getFileHash(bidId);
        uint accepted = bidStore.getAccepted(bidId);
        address hoster = bidStore.getHoster(bidId);

        return (
            fileHash != bytes32(0)
            && !bidStore.isPinned(bidId)
            && (
                accepted == 0
                || now - uint(accepted) >= acceptWait
                || (
                    now - uint(accepted) < acceptWait
                    && hoster == _hoster
                )
            )
        );
    }

    function isBidOpenForPin(int bidId) public view
    returns (bool)
    {
        return isBidOpenForPin(bidId, msg.sender);
    }

    function isBidOpenForAccept(int bidId, address _hoster) public view
    returns (bool)
    {
        uint acceptWait = env.getuint(ENV_ACCEPT_HOLD_DURATION);
        bytes32 fileHash = bidStore.getFileHash(bidId);
        uint accepted = bidStore.getAccepted(bidId);
        address bidder = bidStore.getBidder(bidId);
        return (
            fileHash != bytes32(0)
            && !bidStore.isPinned(bidId)
            && (accepted == 0 || now - uint(accepted) >= acceptWait)
            && bidder != _hoster
        );
    }

    function isBidOpenForAccept(int bidId) public view
    returns (bool)
    {
        return isBidOpenForAccept(bidId, msg.sender);
    }

    function validationSway(int bidId) public view returns (uint)
    {
        uint total = bidStore.getValidationCount(bidId);
        uint sway = 0;
        for (uint i = 0; i < total; i++)
        {
            if (bidStore.getValidationIsValid(bidId, i))
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

    function satisfied(int bidId) public view returns (bool)
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
        
        // Must be a simple majority of minValidations or better
        return(sway >= uint(bids[bidId].minValidations));
    }

    function addValidation(int bidId, bool isValid)
    internal
    {
        require(bids[bidId].pinned > 0, "not open");

        Structures.Validation memory validation = Structures.Validation(
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

    function getBid(int bidId) public view returns (
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

    function getJob() public view returns (int, bytes32, int)
    {
        // TODO: Look into a queue library, maybe?
        // TODO: Test this with thousands(or more) bids
        for (int i=0; i<bidCount; i++)
        {
            if (isBidOpenForAccept(i))
            {
                return (i, bids[i].fileHash, bids[i].fileSize);
            }
        }
        return (-1, 0, 0);
    }

    function getValidation(int bidId, uint idx) public view
    returns (uint, address, bool, bool)
    {
        (
             uint when,
             address validator,
             bool isValid,
             bool paid
        ) = bidStore.getValidation(bidId, idx);
        return (
            when,
            validator,
            isValid,
            paid
        );
    }

    function getValidationCount(int bidId)
    public view returns (uint)
    {
        return bidStore.getValidationCount(bidId);
    }

    function getHoster(int bidId)
    public view returns (address)
    {
        return bidStore.getHoster(bidId);
    }

    function balance(address _address) public view returns (uint)
    {
        return balanceSheet[_address];
    }

    function balance() public view returns (uint)
    {
        return balanceSheet[msg.sender];
    }

    /**
     * Writers
     */

    function setOwner(address payable newOwner)
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
        int fileSize,
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

        // Check value transfer
        if (msg.value < bidValue.add(validationPool))
        {
            emit BidInvalid(fileHash, "no value");
            return false;
        }

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

        int bidId = bidStore.addBid(msg.sender, fileHash, fileSize, bidValue,
                                      validationPool, minValidations,
                                      durationSeconds);

        emit BidSuccessful(bidId, msg.sender, bidValue, validationPool, fileHash, fileSize);

        return true;
    }

    function accept(int bidId) public notBanned
    returns (bool)
    {

        if (!isBidOpenForAccept(bidId))
        {
            emit AcceptWait(now - bids[bidId].accepted);
            return false;
        }

        require(bidStore.setAcceptNow(bidId, msg.sender), "accept error");

        emit Accepted(bidId, msg.sender);

        return true;
    }

    function pinned(int bidId) public notBanned
    returns (bool)
    {
        require(bids[bidId].pinned == 0, "already pinned");

        if (!isBidOpenForPin(bidId))
        {
            emit NotAcceptedByPinner(bidId, bids[bidId].hoster);
            return false;
        }

        require(bidStore.setPinned(bidId, msg.sender), "accept error");

        uint validationPool = bidStore.getValidationPool(bidId);

        // Payout
        uint amountPaid = Rewards.payValidators(address(bidStore), bidId, balanceSheet);
        uint remainder = validationPool - amountPaid;
        if (remainder > 0)
        {
            remainderFunds += remainder;
        }
        Rewards.payHoster(address(bidStore), bidId, balanceSheet);

        bytes32 fileHash = bidStore.getFileHash(bidId);
        emit Pinned(bidId, msg.sender, fileHash);

        return true;
    }

    function validate(int bidId)
    public notBanned
    {
        addValidation(bidId, true);
    }

    function invalidate(int bidId)
    public notBanned
    {
        addValidation(bidId, false);
    }

    function validatorIndex(int bidId, address validator) public view returns (uint)
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

    function transfer(address payable _dest) public notBanned
    {
        uint senderBalance = balanceSheet[msg.sender];

        // Verify
        if (senderBalance == 0)
        {
            emit WithdrawFailed(msg.sender, "zero balance");
            return;
        }
        require(senderBalance < address(this).balance, "not enough funds");

        // Reset and transfer
        balanceSheet[msg.sender] = 0;
        _dest.transfer(senderBalance);

        emit Withdraw(senderBalance, msg.sender);
    }

    function withdraw() public notBanned
    {
        transfer(msg.sender);
    }

}