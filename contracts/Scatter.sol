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
@title Scatter is a contract to handle the lifecycle of bid/accept for IPFS pinning
@author Mike Shultz <mike@mikeshultz.com>

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

    /** constructor(address, address)
     *  @dev initialize the contract
     *  @param  _env        The address of the deployed Env contract
     *  @param _bidStore    The address of the deployed BidStore contract
     */
    constructor(address _env, address _bidStore) public
    {
        owner = msg.sender;
        env = Env(_env);
        bidStore = IBidStore(_bidStore);
    }

    /** satisfied(int)
     *  @notice Has the bid completed it's full lifecycle successfully?
     *  @param  bidId   The bid ID
     *  @return bool If the lifecycle is complete and all requirements are satisfied
     */
    function satisfied(int bidId) external view returns (bool)
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

    /** getBid(int)
     *  @notice Get the main attributes of a bid
     *  @param  bidId   The bid ID
     *  @return address The bidder's address
     *  @return bytes32 The IFPS hash of the file
     *  @return int     The size of the file in bytes
     *  @return uint    The amount of the bid
     *  @return uint    The amount provided to fund validators
     *  @return uint    The duration of the pinning
     *  @return int16   The minimum amount of validators that need to validate the bid
     */
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
        return bidStore.getBid(bidId);
    }

    /** getJob()
     *  @notice Return a bid that needs to be services
     *  @return int     The bid ID
     *  @return bytes32 The IFPS hash of the file
     *  @return int64   The size of the file in bytes
     */
    function getJob() external view returns (int, bytes32, int64)
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

    /** isBidOpenForPin(int, address)
     *  @notice Check if a file for a bid can be pinned by an address
     *  @param  bidId   The bid ID
     *  @param _hoster  The hoster that would like to pin the file
     *  @return bool If the file can be pinned
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

    /** isBidOpenForPin(int)
     *  @notice Check if a file for a bid can be pinned by the sender
     *  @param  bidId   The bid ID
     *  @return bool If the file can be pinned
     */
    function isBidOpenForPin(int bidId) public view
    returns (bool)
    {
        return isBidOpenForPin(bidId, msg.sender);
    }

    /** isBidOpenForAccept(int, address)
     *  @notice Check if a file for a bid can be accepted by an address
     *  @param  bidId   The bid ID
     *  @param _hoster  The hoster that would like to accept the file
     *  @return bool If the file can be accepted
     */
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

    /** isBidOpenForAccept(int)
     *  @notice Check if a file for a bid can be accepted by the sender
     *  @param  bidId   The bid ID
     *  @return bool If the file can be accepted
     */
    function isBidOpenForAccept(int bidId) public view
    returns (bool)
    {
        return isBidOpenForAccept(bidId, msg.sender);
    }

    /** validationSway(int)
     *  @notice Calculate the sway in either direction of validations
     *  @param  bidId   The bid ID
     *  @return uint    The sway, negative or positive
     */
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

    /** getBidCount()
     *  @notice Return the total amount of bids
     *  @return int     The total of known bids
     */
    function getBidCount()
    public view returns (int)
    {
        return bidStore.getBidCount();
    }

    /** getValidation(int, uint)
     *  @notice Get a specific Validation from a bid
     *  @return uint    The timestamp the validation occurred
     *  @return address The validator's address
     *  @return bool    If the validator deamed the pin valid
     *  @return bool    If the validator has been paid
     */
    function getValidation(int bidId, uint idx) public view
    returns (uint, address, bool, bool)
    {
        return bidStore.getValidation(bidId, idx);
    }

    /** getValidationCount(int)
     *  @notice Get the total Validations for a bid
     *  @return uint    The total validations for the provided bid ID
     */
    function getValidationCount(int bidId)
    public view returns (uint)
    {
        return bidStore.getValidationCount(bidId);
    }

    /** getHoster(int)
     *  @notice Get the hoster address set for a bid
     *  @return address The hoster's address
     */
    function getHoster(int bidId)
    public view returns (address)
    {
        return bidStore.getHoster(bidId);
    }

    /** balance(address)
     *  @notice Return the balance of a user's address
     *  @param _address is the address to check
     *  @return uint    The balance of the given address
     */
    function balance(address _address) public view returns (uint)
    {
        return balanceSheet[_address];
    }

    /** balance()
     *  @notice Return the balance of the sender
     *  @return uint    The balance of the sender
     */
    function balance() public view returns (uint)
    {
        return balanceSheet[msg.sender];
    }

    /** bid(bytes32, int64, uint, uint, uint, int16)
     *  @notice Make a bid
     *  @dev This is the mack daddy of functions that kicks off the entire process.  It will
     *      validate, store the bid, and send out an event.
     *  @param fileHash         The IPFS file hash to be pinned
     *  @param fileSize         The size of the file in bytes
     *  @param durationSeconds  The requested duration of the IPFS pin
     *  @param bidValue         The value provided to compensate the hoster
     *  @param validationPool   The value to be split between validators
     *  @param minValidations   The minimum amount of majority validations
     *  @return bool    Succeeded?
     */
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

    /** bid(bytes32, int64, uint, uint, uint)
     *  @notice Make a bid
     *  @dev This is an alias for the other bid function if only the default minValidation is to be
     *      used for this bid.
     *  @param fileHash         The IPFS file hash to be pinned
     *  @param fileSize         The size of the file in bytes
     *  @param durationSeconds  The requested duration of the IPFS pin
     *  @param bidValue         The value provided to compensate the hoster
     *  @param validationPool   The value to be split between validators
     *  @return bool    Succeeded?
     */
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

    /** accept(int)
     *  @notice For a hoster to optionally signal their intention to pin a file. This sets a short
     *      term reservation in place.
     *  @param bidId    The ID of the bid to accept
     *  @return bool    Succeeded?
     */
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

    /** pinned(int)
     *  @notice For a hoster to notify everyone that the pin is in place
     *  @param bidId    The ID of the bid to accept
     *  @return bool    Succeeded?
     */
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

    /** validate(int)
     *  @notice For a validator to mark a pin for a bid as valid
     *  @param bidId    The ID of the bid to be validated
     */
    function validate(int bidId)
    public notBanned
    {
        addValidation(bidId, true);
    }

    /** invalidate(int)
     *  @notice For a validator to mark a pin for a bid as invalid
     *  @param bidId    The ID of the bid to be validated
     */
    function invalidate(int bidId)
    public notBanned
    {
        addValidation(bidId, false);
    }

    /** validatorIndex(int, address payable)
     *  @notice Get the index in the array of a Validation that has a specific address set as
     *      validator
     *  @param bidId        The ID of the bid to be validated
     *  @param validator    The address to look for
     *  @return uint        The array index of the Validation
     */
    function validatorIndex(int bidId, address payable validator) public view returns (uint)
    {

        return bidStore.getValidatorIndex(bidId, validator);

    }

    /** transfer(address payable)
     *  @notice Transfer the sender's entire balance to another address 
     *  @param _dest    The destination address for the funds
     */
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

    /** withdraw()
     *  @notice Transfer the sender's entire balance to their Ethereum account
     */
    function withdraw() public notBanned
    {
        transfer(msg.sender);
    }

    /** payout(int)
     *  @dev Mark the balance sheet with the appropriate funds for a specific bid
     *  @param bidId        The ID of the bid to be validated
     */
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

    /** addValidation(int, bool)
     *  @dev Add a Validation to a bid
     *  @param bidId    The ID of the bid to be validated
     *  @param isValid  If the validator marked the pin as valid
     */
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

    /** validateBid(bytes32, int64, uint, uint, uint, int16)
     *  @dev Validate bid() input values
     *  @param fileHash         The IPFS file hash to be pinned
     *  @param fileSize         The size of the file in bytes
     *  @param durationSeconds  The requested duration of the IPFS pin
     *  @param bidValue         The value provided to compensate the hoster
     *  @param validationPool   The value to be split between validators
     *  @param minValidations   The minimum amount of majority validations
     *  @return bool            If the values passed validation
     */
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