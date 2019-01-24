pragma solidity ^0.5.2;

import "../lib/Owned.sol";
import "../lib/Structures.sol";
import "../interface/IBidStore.sol";
import "../interface/IRouter.sol";


/* BidStore
 * @title The primary persistance contract for storing Bids.
 * @dev This contract is only intended to be used by the Scatter contract.
 * @author Mike Shultz <mike@mikeshultz.com>
 */
contract BidStore is Owned {  // Also is IBidStore, but solc doesn't like that ref

    bytes32 private constant SCATTER_HASH = keccak256("Scatter");

    int public bidCount;
    mapping(int => Structures.Bid) private bids;
    mapping(int => address payable) private stakes;
    address public scatterAddress;
    //address public pinStakeAddress;

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

    /** addBid(address payable, bytes32, int64, uint, uint, int16, uint)
     *  @dev Add a bid to the Store
     *  @param  _sender         The bidder
     *  @param  fileHash        The IPFS file hash
     *  @param  fileSize        The size of the file in bytes
     *  @param  bidValue        The value of the bid to be paid to the pinners
     *  @param  durationSeconds The requested duration of the pin
     *  @param  requiredPinners The amount of pinners required
     *  @return uint            The ID for the bid created
     */
    function addBid(address payable _sender, bytes32 fileHash, int64 fileSize, uint bidValue, 
                    uint durationSeconds, int8 requiredPinners)
    external scatterOnly returns (int)
    {

        int bidID = bidCount;

        bids[bidID].bidder = _sender;
        bids[bidID].fileHash = fileHash;
        bids[bidID].fileSize = fileSize;
        bids[bidID].bidAmount = bidValue;
        bids[bidID].duration = durationSeconds;
        bids[bidID].requiredPinners = requiredPinners;

        bidCount += 1;

        return bidID;
    }

    /** addPinner(int, address payable)
     *  @dev Add a pinner to a Bid
     *  @param  bidID   The ID of the Bid
     *  @param  pinner  The address of the new pinner
     *  @return bool    Success?
     */
    function addPinner(int bidID, address payable pinner)
    external scatterOnly returns (bool)
    {

        uint pinnerIndex = getPinnerIndex(bidID, pinner);

        if (pinnerIndex > uint(-1))
        {
            return false;
        }

        bids[bidID].pinners.push(pinner);

        return true;
    }

    /** getBidCount()
     *  @dev Return the total bids stored in this contract.
     *  @return int     The total bids stored in the contract
     */
    function getBidCount() external view returns (int)
    {
        return bidCount;
    }

    /** isFullyPinned(int)
     *  @dev Is a bid pinned?
     *  @param bidID  The ID of the bid in question
     *  @return bool  If the bid is pinned
     */
    function isFullyPinned(int bidID) external view returns (bool)
    {
        return (bids[bidID].pinners.length >= uint(bids[bidID].requiredPinners));
    }

    /** getPinnerCount(int)
     *  @dev Get the timestamp for the bid's pinning
     *  @param bidID    The ID of the bid in question
     *  @return uint    The amount of pinners
     */
    function getPinnerCount(int bidID) external view returns (uint)
    {
        return bids[bidID].pinners.length;
    }

    /** getPinner(int, uint)
     *  @dev Get the timestamp for the bid's pinning
     *  @param bidID    The ID of the bid in question
     *  @return address The pinner
     */
    function getPinner(int bidID, uint pinnerIndex) external view returns (address)
    {
        return bids[bidID].pinners[pinnerIndex];
    }

    /** getBidder(int)
     *  @dev Return the address for the bidder
     *  @param bidID            The ID of the bid in question
     *  @return address payable The bidder address
     */
    function getBidder(int bidID) external view returns (address payable)
    {
        return bids[bidID].bidder;
    }

    /** getRequiredPinners(int)
     *  @dev Get the timestamp for the bid's acceptance
     *  @param bidID    The ID of the bid in question
     *  @return uint    The timestamp of the accept
     */
    function getRequiredPinners(int bidID) external view returns (int8)
    {
        return bids[bidID].requiredPinners;
    }

    /** getFileHash(int)
     *  @dev Get the fileHash for the bid
     *  @param bidID    The ID of the bid in question
     *  @return bytes32 The IPFS file hash given for the bid
     */
    function getFileHash(int bidID) external view returns (bytes32)
    {
        return bids[bidID].fileHash;
    }

    /** getFileSize(int)
     *  @dev Get the fileSize for the bid
     *  @param bidID  The ID of the bid in question
     *  @return int64 The file size in bytes
     */
    function getFileSize(int bidID) external view returns (int64)
    {
        return bids[bidID].fileSize;
    }

    /** getDuration(int)
     *  @dev Get the requested pin duration for the bid
     *  @param bidID    The ID of the bid in question
     *  @return uint    The pin duration in seconds
     */
    function getDuration(int bidID) external view returns (uint)
    {
        return bids[bidID].duration;
    }

    /** getBidAmount(int)
     *  @dev Get the funds to be paid to the pinners
     *  @param bidID    The ID of the bid in question
     *  @return uint    The amount of Ether to be paid to the pinners
     */
    function getBidAmount(int bidID) external view returns (uint)
    {
        return bids[bidID].bidAmount;
    }

    /** getBid(int)
     *  @dev Get the primary attributes of a Bid
     *  @param bidID    The ID of the bid in question
     *  @return address Address of the bidder
     *  @return bytes32 IPFS File hash
     *  @return int     File size in bytes
     *  @return uint    The amount of the bid in wei
     *  @return uint    The duration in seconds for the pin
     */
    function getBid(int bidID) external view returns (
        address,
        bytes32,
        int,
        uint,
        uint,
        int8
    )
    {
        return(
            bids[bidID].bidder,
            bids[bidID].fileHash,
            bids[bidID].fileSize,
            bids[bidID].bidAmount,
            bids[bidID].duration,
            bids[bidID].requiredPinners
        );
    }

    /** bidExists(int)
     *  @dev Does a bid exist at this ID?
     *  @param bidID    The ID of the bid in question
     *  @return bool    Does it exist?
     */
    function bidExists(int bidID) public view returns (bool)
    {
        if (bids[bidID].bidder == address(0))
        {
            return false;
        }
        return true;
    }

    /** getPinnerIndex(int, address)
     *  @dev Get the index for a pinner
     *  @param bidID    The ID of the bid in question
     *  @param pinner   The address of the pinner to look for
     *  @return uint    The index of the pinner, or -1 if not found
     */
    function getPinnerIndex(int bidID, address pinner) public view returns (uint)
    {
        for (uint i = 0; i < bids[bidID].pinners.length; i++)
        {
            if (bids[bidID].pinners[i] == pinner)
            {
                return i;
            }
        }

        return uint(-1);
    }

    /** setScatter(address)
     *  @dev Set the address for the Scatter contract
     *  @param newAddress The new address for the Scatter contract
     */
    function setScatter(address newAddress) public ownerOnly
    {
        assert(newAddress != address(0));
        scatterAddress = newAddress;
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