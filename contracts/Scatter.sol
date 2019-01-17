pragma solidity >=0.5.2 <0.6.0;

import "./interface/IRouter.sol";
import "./interface/IScatter.sol";

import "./lib/Owned.sol";
import "./lib/SafeMath.sol";
import "./lib/Structures.sol";
import "./lib/Rewards.sol";

import "./storage/Env.sol";
import "./storage/BidStore.sol";


/* Scatter

General steps of use
--------------------
- user bids for hosting (bid())
- hoster accepts, pins the file on their node, then.. (accept())
- hoster marks it as 'pinned' (pinned())
- validators verify that it is indeed pinned on the node (validate()/invalidate())
- the first validator after duration triggers payouts for everyone
*/
contract Scatter is Owned {  /// interface: IScatter
    using SafeMath for uint;

    event BidSuccessful(
        int indexed bidId,
        address indexed bidder,
        uint indexed bidValue,
        uint validationPool,
        bytes32 fileHash,
        int64 fileSize
    );

    event BidInvalid(bytes32 indexed fileHash, string reason);
    event BidTooLow(bytes32 indexed fileHash);
    event Accepted(int indexed bidId, address indexed hoster);
    event AcceptWait(uint waitLeft);
    event Pinned(int indexed bidId, address indexed hoster, bytes32 fileHash);
    event NotAcceptedByPinner(int indexed bidId, address indexed hoster);
    event WithdrawFailed(address indexed sender, string reason);
    event Withdraw(uint indexed value, address indexed hoster);
    event ValidationOcurred(int indexed bidId, address indexed validator, bool indexed isValid);

    Env public env;
    IBidStore public bidStore;

    mapping(address => uint) private balanceSheet;
    uint public remainderFunds;

    // solhint-disable-next-line max-line-length
    bytes32 private constant EMPTY_IPFS_FILE = 0xbfccda787baba32b59c78450ac3d20b633360b43992c77289f9ed46d843561e6;
    bytes32 private constant ENV_ACCEPT_HOLD_DURATION = keccak256("acceptHoldDuration");
    bytes32 private constant ENV_DEFAULT_MIN_VALIDATIONS = keccak256("defaultMinValidations");
    bytes32 private constant ENV_MIN_DURATION = keccak256("minDuration");
    bytes32 private constant ENV_MIN_BID = keccak256("minBid");

    modifier notBanned() { require(!env.isBanned(msg.sender), "banned"); _; }

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
        uint total = bidStore.getValidationCount(bidId);
        uint minValid = uint(bidStore.getMinValidations(bidId));
        if (total < minValid)
        {
            return false;
        }

        uint sway = validationSway(bidId);

        if (sway == 0) // No ties
        {
            return false;
        }
        
        // Must be a simple majority of minValidations or better
        return(sway >= minValid);
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
        return bidStore.getBid(bidId);
    }

    function getJob() public view returns (int, bytes32, int64)
    {
        // TODO: Look into a queue library, maybe?
        // TODO: Test this with thousands(or more) bids
        int totalBids = bidStore.getBidCount();
        for (int i = 0; i < totalBids; i++)
        {
            if (isBidOpenForAccept(i))
            {
                bytes32 fileHash = bidStore.getFileHash(i);
                int64 fileSize = bidStore.getFileSize(i);
                return (i, fileHash, fileSize);
            }
        }
        return (-1, 0, 0);
    }

    function getBidCount()
    external view returns (int)
    {
        return bidStore.getBidCount();
    }

    function getValidation(int bidId, uint idx) public view
    returns (uint, address, bool, bool)
    {
        return bidStore.getValidation(bidId, idx);
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
        uint validationPool,
        int16 minValidations
    )
    public notBanned
    payable
    returns (bool)
    {

        if (!validateBid(fileHash, fileSize, durationSeconds, bidValue, validationPool,
            minValidations))
        {
            emit BidInvalid(fileHash, "failed validation");
            return false;
        }

        int bidId = bidStore.addBid(msg.sender, fileHash, fileSize, bidValue, validationPool,
                                    minValidations, durationSeconds);

        assert(bidId > -1);

        emit BidSuccessful(
            bidId,
            address(msg.sender),
            bidValue,
            validationPool,
            fileHash,
            fileSize
        );

        return true;
    }

    function bid(
        bytes32 fileHash,
        int64 fileSize,
        uint durationSeconds,
        uint bidValue,
        uint validationPool
    )
    public
    payable
    returns (bool)
    {
        // Use the minimum validations default from the Env contract
        uint minValid = env.getuint(ENV_DEFAULT_MIN_VALIDATIONS);
        return bid(fileHash, fileSize, durationSeconds, bidValue, validationPool, int16(minValid));
    }

    function accept(int bidId) public notBanned
    returns (bool)
    {

        if (!isBidOpenForAccept(bidId))
        {
            uint accepted = bidStore.getAccepted(bidId);
            emit AcceptWait(now - accepted);
            return false;
        }

        require(bidStore.setAcceptNow(bidId, msg.sender), "accept error");

        emit Accepted(bidId, msg.sender);

        return true;
    }

    function pinned(int bidId) public notBanned
    returns (bool)
    {
        require(!bidStore.isPinned(bidId), "already pinned");

        if (!isBidOpenForPin(bidId))
        {
            address storedHoster = bidStore.getHoster(bidId);
            emit NotAcceptedByPinner(bidId, storedHoster);
            return false;
        }

        require(bidStore.setPinned(bidId, msg.sender), "accept error");

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

    function validatorIndex(int bidId, address payable validator) public view returns (uint)
    {

        return bidStore.getValidatorIndex(bidId, validator);

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

    function payout(int bidId)
    internal
    {
        uint validationPool = bidStore.getValidationPool(bidId);

        // Payout
        require(bidStore.getValidationCount(bidId) > 0, "non validators");
        uint amountPaid = Rewards.payValidators(address(bidStore), bidId, balanceSheet);

        uint remainder = validationPool - amountPaid;
        if (remainder > 0)
        {
            remainderFunds += remainder;
        }
        Rewards.payHoster(address(bidStore), bidId, balanceSheet);
    }

    function addValidation(int bidId, bool isValid)
    internal
    {
        require(bidStore.isPinned(bidId), "not open");
        require(bidStore.addValidation(bidId, msg.sender, isValid), "add failed");

        uint whenPinned = bidStore.getPinned(bidId);
        uint durationSeconds = bidStore.getDuration(bidId);
        if (Rewards.durationHasPassed(whenPinned, durationSeconds))
        {
            payout(bidId);
        }

        emit ValidationOcurred(bidId, msg.sender, isValid);
    }

    function validateBid(
        bytes32 fileHash,
        int64 fileSize,
        uint durationSeconds,
        uint bidValue,
        uint validationPool,
        int16 minValidations
    ) internal view returns (bool)
    {
        if (
            msg.value < bidValue.add(validationPool)
            || fileHash == bytes32(0) || fileSize < 1
            || fileHash == EMPTY_IPFS_FILE
            || bidValue < 1
            || validationPool < uint(minValidations)
            || bidValue < env.getuint(ENV_MIN_BID)
            || durationSeconds < env.getuint(ENV_MIN_DURATION)
        )
        {
            return false;
        }

        return true;
    }

}