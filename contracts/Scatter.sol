pragma solidity >=0.5.2 <0.6.0;

import "./interface/IRouter.sol";
import "./interface/IScatter.sol";
import "./interface/IPinStake.sol";
import "./interface/IPinChallenge.sol";
import "./interface/IBidStore.sol";
import "./interface/IChallengeStore.sol";
import "./interface/IDefenseStore.sol";

import "./lib/Owned.sol";
import "./lib/SafeMath.sol";
import "./lib/Structures.sol";
import "./lib/SLib.sol";

import "./storage/Env.sol";


/* Scatter
@title Scatter is a contract to handle the lifecycle of bid/accept for IPFS pinning
@author Mike Shultz <mike@mikeshultz.com>

General steps of use
--------------------
- user bids for hosting (bid())
- pinner stakes
- pinner marks it as 'pinned' (pinned())
- TODO: more
*/
contract Scatter is Owned {  /// interface: IScatter
    using SafeMath for uint;

    event BidSuccessful(
        uint indexed bidID,
        address indexed bidder,
        uint indexed bidValue,
        bytes32 fileHash,
        uint64 fileSize
    );

    event BidInvalid(bytes32 indexed fileHash, string reason);
    event BidTooLow(bytes32 indexed fileHash);
    event FilePinned(uint indexed bidID, address indexed pinner, bytes32 fileHash);
    event NotOpenToPin(uint indexed bidID, address indexed pinner);
    event WithdrawFailed(address indexed sender, string reason);
    event WithdrawFunds(uint indexed value, address indexed payee);

    event NotStaker(uint indexed bidID, address indexed sender);
    event PinStake(uint indexed bidID, address indexed pinner);
    event PinStakeInvalid(uint indexed bidID, address indexed staker);
    event AlreadyStaked(uint indexed bidID, address indexed sender);

    Env public env;
    IBidStore public bidStore;
    IChallengeStore public challengeStore;
    IPinChallenge public pinChallenge;
    IDefenseStore public defenseStore;
    IPinStake public pinStake;
    IRouter public router;

    mapping(address => uint) private balanceSheet;
    uint public balanceSheetTotal;
    uint public stakeBalance;
    uint public remainderFunds;  // What TODO with this?

    // solhint-disable-next-line max-line-length
    bytes32 private constant EMPTY_IPFS_FILE = 0xbfccda787baba32b59c78450ac3d20b633360b43992c77289f9ed46d843561e6;
    bytes32 private constant ENV_REQUIRED_PINNERS = keccak256("requiredPinners");
    bytes32 private constant ENV_MIN_DURATION = keccak256("minDuration");
    bytes32 private constant ENV_MIN_BID = keccak256("minBid");
    bytes32 private constant ENV_HASH = keccak256("Env");
    bytes32 private constant BID_STORE_HASH = keccak256("BidStore");
    bytes32 private constant CHALLENGE_STORE_HASH = keccak256("ChallengeStore");
    bytes32 private constant DEFENSE_STORE_HASH = keccak256("DefenseStore");
    bytes32 private constant PIN_STAKE_HASH = keccak256("PinStake");
    bytes32 private constant PIN_CHALLENGE_HASH = keccak256("PinChallenge");

    modifier notBanned() { require(!env.isBanned(msg.sender), "banned"); _; }
    modifier pinChallengeOnly() { require(msg.sender == address(pinChallenge), "PC only"); _; }

    /** constructor(address, address)
     *  @dev initialize the contract
     *  @param  _router    The address of the Router contract
     */
    constructor(address _router) public
    {
        router = IRouter(_router);
        updateReferences();
    }

    /** satisfied(uint)
     *  @notice Has the bid completed it's full lifecycle successfully?
     *  @param  bidID   The bid ID
     *  @return bool If the lifecycle is complete and all requirements are satisfied
     */
    function satisfied(uint bidID) external view returns (bool)
    {
        uint challengeCount = bidStore.getChallengeCount(bidID);
        if (challengeCount > 0)
        {
            uint latestChallengeID = bidStore.getChallengeID(bidID, challengeCount);
            // If an open challenge hasn't been defended, not satisfied
            if (!challengeStore.getDefended(latestChallengeID))
            {
                return false;
            }
        }
        return(uint8(bidStore.getPinnerCount(bidID)) >= bidStore.getRequiredPinners(bidID));
    }

    function hashBytes32(bytes32 toHash) external pure returns (bytes32)
    {
        return SLib.hashBytes32(toHash);
    }

    function verifySignature(address signer, bytes32 hash, uint8 v, bytes32 r,
        bytes32 s)
    external pure returns (bool)
    {
        return SLib.verifySignature(signer, hash, v, r, s);
    }

    /** audit()
     *  @notice Do a simplistic audit of internal funds tracking
     *  @return bool  Do the numbers line up?
     */
    function audit() external view returns (bool)
    {
        uint contractBalance = address(this).balance;
        return (balanceSheetTotal + remainderFunds == contractBalance);
    }

    /** getBid(uint)
     *  @notice Get the main attributes of a bid
     *  @param  bidID   The bid ID
     *  @return address The bidder's address
     *  @return bytes32 The IFPS hash of the file
     *  @return uint     The size of the file in bytes
     *  @return uint    The amount of the bid
     *  @return uint    The duration of the pinning
     *  @return uint8    The amount of required pinners
     */
    function getBid(uint bidID) external view returns (
        address,
        bytes32,
        uint,
        uint,
        uint,
        uint8
    )
    {
        return bidStore.getBid(bidID);
    }

    /** isBidOpenForPin(uint, address)
     *  @notice Check if a file for a bid can be pinned by an address
     *  @param  bidID   The bid ID
     *  @param _pinner  The pinner that would like to pin the file
     *  @return bool If the file can be pinned
     */
    function isBidOpenForPin(uint bidID, address payable _pinner) public view
    returns (bool)
    {
        bytes32 fileHash = bidStore.getFileHash(bidID);
        uint valueStaked = pinStake.getStakeValue(bidID, _pinner);
        uint bidAmount = bidStore.getBidAmount(bidID);

        return (
            fileHash != bytes32(0)
            && valueStaked >= bidAmount.div(2)
        );
    }

    /** isBidOpenForPin(uint)
     *  @notice Check if a file for a bid can be pinned by the sender
     *  @param  bidID   The bid ID
     *  @return bool If the file can be pinned
     */
    function isBidOpenForPin(uint bidID) public view
    returns (bool)
    {
        return isBidOpenForPin(bidID, msg.sender);
    }

    /** isBidOpenForStake(uint, address)
     *  @notice Check if a file for a bid can be staked by an address
     *  @param  bidID   The bid ID
     *  @param _pinner  The potential staker
     *  @return bool If the file can be staked
     */
    function isBidOpenForStake(uint bidID, address _pinner) public view
    returns (bool)
    {
        bytes32 fileHash = bidStore.getFileHash(bidID);
        uint8 requiredPinners = bidStore.getRequiredPinners(bidID);
        uint stakeCount = pinStake.getStakeCount(bidID);
        address bidder = bidStore.getBidder(bidID);
        return (
            fileHash != bytes32(0)
            && !bidStore.isFullyPinned(bidID)
            && uint8(stakeCount) < requiredPinners
            && bidder != _pinner
        );
    }

    /** isBidOpenForStake(uint)
     *  @notice Check if a file for a bid can be accepted by the sender
     *  @param  bidID   The bid ID
     *  @return bool If the file can be accepted
     */
    function isBidOpenForStake(uint bidID) public view
    returns (bool)
    {
        return isBidOpenForStake(bidID, msg.sender);
    }

    /** getBidCount()
     *  @notice Return the total amount of bids
     *  @return uint     The total of known bids
     */
    function getBidCount()
    public view returns (uint)
    {
        return bidStore.getBidCount();
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

    /** bid(bytes32, uint64, uint, uint, uint, uint16)
     *  @notice Make a bid
     *  @dev This is the mack daddy of functions that kicks off the entire process.  It will
     *      validate, store the bid, and send out an event.
     *  @param fileHash         The IPFS file hash to be pinned
     *  @param fileSize         The size of the file in bytes
     *  @param durationSeconds  The requested duration of the IPFS pin
     *  @param bidValue         The value provided to compensate the pinners
     *  @param requiredPinners  The amount of pinners the bid requires
     *  @return bool    Succeeded?
     */
    function bid(
        bytes32 fileHash,
        uint64 fileSize,
        uint durationSeconds,
        uint bidValue,
        uint8 requiredPinners
    )
    public notBanned
    payable
    returns (bool)
    {

        if (!validateBid(fileHash, fileSize, durationSeconds, bidValue))
        {
            emit BidInvalid(fileHash, "failed validation");
            return false;
        }

        uint bidID = bidStore.addBid(msg.sender, fileHash, fileSize, bidValue, durationSeconds,
            requiredPinners);

        // For internal accounting
        balanceSheetTotal += msg.value;

        emit BidSuccessful(
            bidID,
            address(msg.sender),
            bidValue,
            fileHash,
            fileSize
        );

        return true;
    }

    /** bid(bytes32, uint64, uint, uint, uint)
     *  @notice Make a bid
     *  @dev This is an alias for the other bid function if only the default requiredPinners is to
     *      be used for this bid.
     *  @param fileHash         The IPFS file hash to be pinned
     *  @param fileSize         The size of the file in bytes
     *  @param durationSeconds  The requested duration of the IPFS pin
     *  @param bidValue         The value provided to compensate the pinners
     *  @return bool    Succeeded?
     */
    function bid(
        bytes32 fileHash,
        uint64 fileSize,
        uint durationSeconds,
        uint bidValue
    )
    public
    payable
    returns (bool)
    {
        // Use the minimum pinners default from the Env contract
        uint requiredPinners = env.getuint(ENV_REQUIRED_PINNERS);
        return bid(fileHash, fileSize, durationSeconds, bidValue, uint8(requiredPinners));
    }

    /** stake(bidID)
     *  @notice Add a stake to show your intention to pin a file for a bid
     *  @param bidID    The ID of the bid to accept
     *  @return bool    Succeeded?
     */
    function stake(uint bidID) public notBanned payable
    returns (bool)
    {
        require(msg.value > 0, "no value");

        if (!isBidOpenForStake(bidID))
        {
            emit PinStakeInvalid(bidID, msg.sender);
            return false;
        }

        if (!bidStore.bidExists(bidID))
        {
            emit PinStakeInvalid(bidID, msg.sender);
            return false;
        }

        uint valueStaked = pinStake.getStakeValue(bidID, msg.sender);
        uint bidAmount = bidStore.getBidAmount(bidID);
        uint requiredPinners = env.getuint(ENV_REQUIRED_PINNERS);
        if (valueStaked >= bidAmount.div(requiredPinners))
        {
            emit AlreadyStaked(bidID, msg.sender);
            return false;
        }

        // If they havent staked, add the stake
        if (valueStaked < 1)
        {
            require(pinStake.addStake(bidID, msg.value, msg.sender), "failed");
        }
        // Otherwise, add this new vlaue
        else
        {
            require(pinStake.addStakeValue(bidID, msg.value, msg.sender), "value add failed");
        }

        stakeBalance += msg.value; // Internal accounting

        emit PinStake(bidID, msg.sender);
    }

    /** pinned(uint)
     *  @notice For a hoster to notify everyone that the pin is in place
     *  @param bidID    The ID of the bid to accept
     *  @return bool    Succeeded?
     */
    function pinned(uint bidID) public notBanned
    returns (bool)
    {
        require(!bidStore.isFullyPinned(bidID), "already pinned");

        if (!isBidOpenForPin(bidID))
        {
            emit NotOpenToPin(bidID, msg.sender);
            return false;
        }

        require(bidStore.addPinner(bidID, msg.sender), "failed");

        // If this is the final pinner, create the initial challenge
        if (bidStore.getPinnerCount(bidID) == bidStore.getRequiredPinners(bidID))
        {
            require(pinChallenge.challenge(bidID) > 0, "challenge failed");
        }

        bytes32 fileHash = bidStore.getFileHash(bidID);
        emit FilePinned(bidID, msg.sender, fileHash);

        return true;
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
        balanceSheetTotal -= senderBalance;

        emit WithdrawFunds(senderBalance, msg.sender);
    }

    /** withdraw()
     *  @notice Transfer the sender's entire balance to their Ethereum account
     */
    function withdraw() public notBanned
    {
        transfer(msg.sender);
    }

    /** burnStakes(uint)
     *  @notice Burn all stakes for a challenge
     *  @param challengeID  The Challenge ID
     *  @return bull        Success?
     */
    function burnStakes(uint challengeID) public pinChallengeOnly returns (bool)
    {
        uint burnedEther = 0;

        uint bidID = challengeStore.getBidID(challengeID);

        for (uint i = 0; i < challengeStore.getDefenseCount(challengeID); i++)
        {
            uint defenseID = challengeStore.getDefenseID(challengeID, i);
            address payable pinner = defenseStore.getPinner(defenseID);
            burnedEther += pinStake.getStakeValue(bidID, pinner);
        }

        require(pinStake.burnStakes(bidID), "burn failed");
        
        if (burnedEther < 1)
        {
            return false;
        }

        // For internal accounting
        stakeBalance -= burnedEther;
        remainderFunds += burnedEther;

        return true;
    }

    /** updateReferences()
     *  @dev Using the router, update all the addresses
     *  @return bool If anything was updated
     */
    function updateReferences() public ownerOnly returns (bool)
    {
        bool updated = false;

        address newEnvAddress = router.get(ENV_HASH);
        if (newEnvAddress != address(env))
        {
            env = Env(newEnvAddress);
            updated = true;
        }

        address newBSAddress = router.get(BID_STORE_HASH);
        if (newBSAddress != address(bidStore))
        {
            bidStore = IBidStore(newBSAddress);
            updated = true;
        }

        address newCSAddress = router.get(CHALLENGE_STORE_HASH);
        if (newCSAddress != address(challengeStore))
        {
            challengeStore = IChallengeStore(newCSAddress);
            updated = true;
        }

        address newDSAddress = router.get(DEFENSE_STORE_HASH);
        if (newDSAddress != address(defenseStore))
        {
            defenseStore = IDefenseStore(newDSAddress);
            updated = true;
        }

        address newPSAddress = router.get(PIN_STAKE_HASH);
        if (newPSAddress != address(pinStake))
        {
            pinStake = IPinStake(newPSAddress);
            updated = true;
        }

        address newPCAddress = router.get(PIN_CHALLENGE_HASH);
        if (newPCAddress != address(pinChallenge))
        {
            pinChallenge = IPinChallenge(newPCAddress);
            updated = true;
        }
        return updated;
    }

    /*TODO
    function payout(int bidID)
    internal
    {
        uint validationPool = bidStore.getValidationPool(bidID);

        // Payout
        require(bidStore.getValidationCount(bidID) > 0, "non validators");
        uint amountPaid = Rewards.payValidators(address(bidStore), bidID, balanceSheet);

        uint remainder = validationPool - amountPaid;
        if (remainder > 0)
        {
            remainderFunds += remainder;
        }
        Rewards.payHoster(address(bidStore), bidID, balanceSheet);
    }*/

    /** validateBid(bytes32, int64, uint, uint, uint, int16)
     *  @dev Validate bid() input values
     *  @param fileHash         The IPFS file hash to be pinned
     *  @param fileSize         The size of the file in bytes
     *  @param durationSeconds  The requested duration of the IPFS pin
     *  @param bidValue         The value provided to compensate the hoster
     *  @return bool            If the values passed validation
     */
    function validateBid(
        bytes32 fileHash,
        uint64 fileSize,
        uint durationSeconds,
        uint bidValue
    ) internal view returns (bool)
    {
        if (
            msg.value < bidValue
            || fileHash == bytes32(0) || fileSize < 1
            || fileHash == EMPTY_IPFS_FILE
            || bidValue < 1
            || bidValue < env.getuint(ENV_MIN_BID)
            || durationSeconds < env.getuint(ENV_MIN_DURATION)
        )
        {
            return false;
        }

        return true;
    }

}