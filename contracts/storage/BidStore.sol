pragma solidity ^0.5.2;

import "../lib/Owned.sol";
import "../lib/Structures.sol";
import "../interface/IBidStore.sol";
import "../interface/IRouter.sol";


/* BidStore
 * @title The primary persistance contract for storing Bids and Validations.
 * @dev This contract is only intended to be used by the Scatter contract.
 * @author Mike Shultz <mike@mikeshultz.com>
 */
contract BidStore is Owned {  // Also is IBidStore, but solc doesn't like that ref

    bytes32 private constant SCATTER_HASH = keccak256("Scatter");

    int public bidCount;
    mapping(int => Structures.Bid) private bids;
    mapping(int => Structures.Validation[]) private validations;
    address public scatterAddress;

    IRouter public router;

    modifier scatterOnly() {
        require(msg.sender == scatterAddress, "not allowed");
        _;
    }

    /** constructor(address)
     *  @dev initialize the contract
     *  @param  _router    The address of the Router contract
     */
    constructor(address _router) public {
        router = IRouter(_router);
        updateReferences();
    }

    /** addValidation(int, address payable, bool)
     *  @dev Add a validation to a bid
     *  @param  bidId       The ID of the bid to add the validation to
     *  @param  _validator  The address of the validator
     *  @param  _isValid    Whether or not the pin was marked valid
     *  @return bool Success?
     */
    function addValidation(int bidId, address payable _validator, bool _isValid)
    external scatterOnly returns (bool)
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

        validations[bidId].push(vlad);

        return true;
    }

    /** setValidatorPaid(int, uint)
     *  @dev Set the Validation as paid
     *  @param  bidId   The ID of the bid to add the validation to
     *  @param  idx     The index of the Validation to set paid
     *  @return bool Success?
     */
    function setValidatorPaid(int bidId, uint idx) external scatterOnly returns (bool)
    {
        if (validations[bidId][idx].when == 0)
        {
            return false;
        }

        validations[bidId][idx].paid = true;
        return true;
    }

    /** setHoster(int, address payable)
     *  @dev Set the hoster for a bid
     *  @param  bidId   The ID of the bid to add the validation to
     *  @param  _hoster The address of the hoster account
     *  @return bool Success?
     */
    function setHoster(int bidId, address payable _hoster) external scatterOnly returns (bool)
    {
        if (bids[bidId].bidder == address(0))
        {
            return false;
        }

        bids[bidId].hoster = _hoster;
        return true;
    }

    /** setHosterPaid(int)
     *  @dev Set the bid as paid
     *  @param  bidId   The ID of the bid to add the validation to
     *  @return bool Success?
     */
    function setHosterPaid(int bidId) external scatterOnly returns (bool)
    {
        if (bids[bidId].bidder == address(0) || bids[bidId].hoster == address(0))
        {
            return false;
        }

        bids[bidId].paid = true;
        return true;
    }

    /** setAcceptNow(int, address payable)
     *  @dev Set the bid as accepted and set the hoster
     *  @param  bidId   The ID of the bid to add the validation to
     *  @param  hoster  The address of the hoster account
     *  @return bool Success?
     */
    function setAcceptNow(int bidId, address payable hoster) external scatterOnly returns (bool)
    {
        if (bids[bidId].bidder == address(0))
        {
            return false;
        }

        bids[bidId].accepted = now;
        bids[bidId].hoster = hoster;
        return true;
    }

    /** setPinned(int, address payable)
     *  @dev Set the bid as pinned and set the hoster
     *  @param  bidId   The ID of the bid to add the validation to
     *  @param  hoster  The address of the hoster account
     *  @return bool Success?
     */
    function setPinned(int bidId, address payable hoster) external scatterOnly returns (bool)
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

    /** addBid(address payable, bytes32, int64, uint, uint, int16, uint)
     *  @dev Add a bid to the Store
     *  @param  _sender         The bidder
     *  @param  fileHash        The IPFS file hash
     *  @param  fileSize        The size of the file in bytes
     *  @param  bidValue        The value of the bid to be paid to the hoster
     *  @param  validationPool  The funds to be split by validators
     *  @param  minValidations  Minimum validations for the bid
     *  @param  durationSeconds The requested duration of the pin
     *  @return uint            The ID for the bid created
     */
    function addBid(address payable _sender, bytes32 fileHash, int64 fileSize, uint bidValue, 
                    uint validationPool, int16 minValidations, uint durationSeconds)
    external scatterOnly returns (int)
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

    /** getBidCount()
     *  @dev Return the total bids stored in this contract.
     *  @return int     The total bids stored in the contract
     */
    function getBidCount() external view returns (int)
    {
        return bidCount;
    }

    /** isPinned(int)
     *  @dev Is a bid pinned?
     *  @param bidId  The ID of the bid in question
     *  @return bool  If the bid is pinned
     */
    function isPinned(int bidId) external view returns (bool)
    {
        return (bids[bidId].pinned > 0);
    }

    /** getPinned(int)
     *  @dev Get the timestamp for the bid's pinning
     *  @param bidId    The ID of the bid in question
     *  @return uint    The timestamp of the pin
     */
    function getPinned(int bidId) external view returns (uint)
    {
        return bids[bidId].pinned;
    }

    /** getBidder(int)
     *  @dev Return the address for the bidder
     *  @param bidId            The ID of the bid in question
     *  @return address payable The bidder address
     */
    function getBidder(int bidId) external view returns (address payable)
    {
        return bids[bidId].bidder;
    }

    /** getAccepted(int)
     *  @dev Get the timestamp for the bid's acceptance
     *  @param bidId    The ID of the bid in question
     *  @return uint    The timestamp of the accept
     */
    function getAccepted(int bidId) external view returns (uint)
    {
        return bids[bidId].accepted;
    }

    /** getHoster(int)
     *  @dev Get the hoster for the bid
     *  @param bidId    The ID of the bid in question
     *  @return address The address for the hoster
     */
    function getHoster(int bidId) external view returns (address)
    {
        return bids[bidId].hoster;
    }

    /** getFileHash(int)
     *  @dev Get the fileHash for the bid
     *  @param bidId    The ID of the bid in question
     *  @return bytes32 The IPFS file hash given for the bid
     */
    function getFileHash(int bidId) external view returns (bytes32)
    {
        return bids[bidId].fileHash;
    }

    /** getFileSize(int)
     *  @dev Get the fileSize for the bid
     *  @param bidId  The ID of the bid in question
     *  @return int64 The file size in bytes
     */
    function getFileSize(int bidId) external view returns (int64)
    {
        return bids[bidId].fileSize;
    }

    /** getDuration(int)
     *  @dev Get the requested pin duration for the bid
     *  @param bidId    The ID of the bid in question
     *  @return uint    The pin duration in seconds
     */
    function getDuration(int bidId) external view returns (uint)
    {
        return bids[bidId].duration;
    }

    /** getValidationPool(int)
     *  @dev Get the funds to be split between validators
     *  @param bidId    The ID of the bid in question
     *  @return uint    The pin validation pool fund total
     */
    function getValidationPool(int bidId) external view returns (uint)
    {
        return bids[bidId].validationPool;
    }

    /** getBidAmount(int)
     *  @dev Get the funds to be paid to the hoster
     *  @param bidId    The ID of the bid in question
     *  @return uint    The amount of Ether to be paid to the hoster
     */
    function getBidAmount(int bidId) external view returns (uint)
    {
        return bids[bidId].bidAmount;
    }

    /** getMinValidations(int)
     *  @dev The minimum validations set for a bid
     *  @param bidId    The ID of the bid in question
     *  @return int16   The amount of validations needed for a bid to be satisfied
     */
    function getMinValidations(int bidId) external view returns (int16)
    {
        return bids[bidId].minValidations;
    }

    /** getValidationCount(int)
     *  @dev Get the total validations performed for a pin
     *  @param bidId    The ID of the bid in question
     *  @return uint    The total validations assigned to a pin
     */
    function getValidationCount(int bidId) external view returns (uint)
    {
        return validations[bidId].length;
    }

    /** getValidatorIndex(int, address payable)
     *  @dev Get the Validation index of a specific validator account
     *  @param bidId        The ID of the bid in question
     *  @param _validator   The address of the validator to look for.
     *  @return uint        The index for the validator in the Bid
     */
    function getValidatorIndex(int bidId, address payable _validator) external view returns (uint)
    {
        if (bids[bidId].bidder == address(0))
        {
            return uint(-1);
        }

        for (uint i = 0; i < validations[bidId].length; i++)
        {
            if (validations[bidId][i].validator == _validator)
            {
                return i;
            }
        }

        return uint(-1);
    }
    
    /** getValidator(int, uint)
     *  @dev Return the validator address at a specifc index
     *  @param bidId            The ID of the bid in question
     *  @param idx              The Validation index to return
     *  @return address payable The validator address at the index
     */
    function getValidator(int bidId, uint idx) external view returns (address payable)
    {
        return validations[bidId][idx].validator;
    }

    /** getValidation(int, uint)
     *  @dev Return the key attributes for a Validation and an index
     *  @param bidId    The ID of the bid in question
     *  @param idx      The Validation index to return
     *  @return uint    The timestamp of the validation
     *  @return address The address of the validator
     *  @return bool    Did the validator validate?
     *  @return bool    Has the validator been paid?
     */
    function getValidation(int bidId, uint idx) external view returns (
        uint,       // when
        address,    // validator
        bool,       // isValid
        bool        // paid
    )
    {
        return (
            validations[bidId][idx].when,
            validations[bidId][idx].validator,
            validations[bidId][idx].isValid,
            validations[bidId][idx].paid
        );
    }

    /** getValidationIsValid(int, uint)
     *  @dev Did the specific validation mark the pin as valid?
     *  @param bidId    The ID of the bid in question
     *  @param idx      The Validation index to return
     *  @return bool    Did the validator validate?
     */
    function getValidationIsValid(int bidId, uint idx) external view returns (bool)
    {
        return validations[bidId][idx].isValid;
    }

    /** bidExists(int)
     *  @dev Does a bid exist at this ID?
     *  @param bidId    The ID of the bid in question
     *  @return bool    Does it exist?
     */
    function bidExists(int bidId) external view returns (bool)
    {
        if (bids[bidId].bidder == address(0))
        {
            return false;
        }
        return true;
    }

    /** bidExists(int)
     *  @dev Get the primary attributes of a Bid
     *  @param bidId    The ID of the bid in question
     *  @return address Address of the bidder
     *  @return bytes32 IPFS File hash
     *  @return int     File size in bytes
     *  @return uint    The amount of the bid in wei
     *  @return uint    The amount to be split by validators in wei
     *  @return uint    The duration in seconds for the pin
     *  @return int16   The minimum validations
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

    /** setScatter(address)
     *  @dev Set the address for the Scatter contract
     *  @param _newAddress The new address for the Scatter contract
     */
    function setScatter(address _newAddress) public ownerOnly
    {
        assert(_newAddress != address(0));
        scatterAddress = _newAddress;
    }

    /** setBidCount(int)
     *  @dev Set the bidCount sequence.  WARNING: This is for emergencies!
     *  @param _bidCount The new bidCount value
     */
    function setBidCount(int _bidCount) public ownerOnly
    {
        bidCount = _bidCount;
    }

    /** updateReferences()
     *  @dev Using the router, update all the addresses
     *  @return bool If anything was updated
     */
    function updateReferences() public ownerOnly returns (bool)
    {
        bool updated = false;
        address newScatterAddress = router.get(SCATTER_HASH);
        if (newScatterAddress != scatterAddress)
        {
            scatterAddress = newScatterAddress;
            updated = true;
        }
        return updated;
    }

}