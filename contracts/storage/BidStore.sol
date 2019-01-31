pragma solidity ^0.5.2;

import "../lib/Owned.sol";
import "../lib/WriteRestricted.sol";
import "../lib/Structures.sol";
import "../interface/IBidStore.sol";
import "../interface/IRouter.sol";


/* BidStore
 * @title The primary persistance contract for storing Bids.
 * @dev This contract is only intended to be used by the Scatter contract.
 * @author Mike Shultz <mike@mikeshultz.com>
 */
contract BidStore is Owned, WriteRestricted {  // Also is IBidStore, but solc doesn't like that ref

    bytes32 private constant SCATTER_HASH = keccak256("Scatter");

    uint public nextBidID;
    mapping(uint => Structures.Bid) private bids;

    /** constructor(address)
     *  @dev initialize the contract
     */
    constructor() public {
        nextBidID = 1;
    }

    /** addBid(address payable, bytes32, uint64, uint, uint, uint16, uint)
     *  @dev Add a bid to the Store
     *  @param  _sender         The bidder
     *  @param  fileHash        The IPFS file hash
     *  @param  fileSize        The size of the file in bytes
     *  @param  bidValue        The value of the bid to be paid to the pinners
     *  @param  durationSeconds The requested duration of the pin
     *  @param  requiredPinners The amount of pinners required
     *  @return uint            The ID for the bid created
     */
    function addBid(address payable _sender, bytes32 fileHash, uint64 fileSize, uint bidValue, 
                    uint durationSeconds, uint8 requiredPinners)
    external writersOnly returns (uint)
    {

        uint bidID = nextBidID;

        bids[bidID].bidder = _sender;
        bids[bidID].when = now;
        bids[bidID].fileHash = fileHash;
        bids[bidID].fileSize = fileSize;
        bids[bidID].bidAmount = bidValue;
        bids[bidID].duration = durationSeconds;
        bids[bidID].requiredPinners = requiredPinners;

        nextBidID += 1;

        return bidID;
    }

    /** addPinner(uint, address payable)
     *  @dev Add a pinner to a Bid
     *  @param  bidID   The ID of the Bid
     *  @param  pinner  The address of the new pinner
     *  @return bool    Success?
     */
    function addPinner(uint bidID, address payable pinner)
    external writersOnly returns (bool)
    {
        if (!bidExists(bidID))
        {
            return false;
        }

        if (pinnerExists(bidID, pinner))
        {
            return false;
        }

        bids[bidID].pinners.push(pinner);

        return true;
    }

    /** addChallenge(uint, uint)
     *  @dev Add a challengeID to a Bid
     *  @param  bidID           The ID of the Bid
     *  @param  challengeID     The Challenge ID to add
     *  @return bool    Success?
     */
    function addChallenge(uint bidID, uint challengeID)
    external writersOnly returns (bool)
    {

        bids[bidID].challenges.push(challengeID);

        return true;
    }

    /** getBidCount()
     *  @dev Return the total bids stored in this contract.
     *  @return uint     The total bids stored in the contract
     */
    function getBidCount() external view returns (uint)
    {
        return nextBidID - 1;
    }

    /** isFullyPinned(uint)
     *  @dev Is a bid pinned?
     *  @param bidID  The ID of the bid in question
     *  @return bool  If the bid is pinned
     */
    function isFullyPinned(uint bidID) external view returns (bool)
    {
        return (bids[bidID].pinners.length >= uint(bids[bidID].requiredPinners));
    }

    /** getPinnerCount(uint)
     *  @dev Get the timestamp for the bid's pinning
     *  @param bidID    The ID of the bid in question
     *  @return uint    The amount of pinners
     */
    function getPinnerCount(uint bidID) external view returns (uint)
    {
        return bids[bidID].pinners.length;
    }

    /** getPinner(uint, uint)
     *  @dev Get the timestamp for the bid's pinning
     *  @param bidID    The ID of the bid in question
     *  @return address The pinner
     */
    function getPinner(uint bidID, uint pinnerIndex) external view returns (address)
    {
        return bids[bidID].pinners[pinnerIndex];
    }

    /** getChallengeCount(uint)
     *  @dev Get the total Challenges for a bid
     *  @param bidID    The ID of the bid in question
     *  @return uint    The amount of challenges
     */
    function getChallengeCount(uint bidID) external view returns (uint)
    {
        return bids[bidID].challenges.length;
    }

    /** getChallengeID(uint, uint)
     *  @dev Get the timestamp for the bid's pinning
     *  @param bidID    The ID of the bid in question
     *  @param index    The array index to return
     *  @return uint     The Challenge ID
     */
    function getChallengeID(uint bidID, uint index) external view returns (uint)
    {
        return bids[bidID].challenges[index];
    }

    /** getBidder(uint)
     *  @dev Return the address for the bidder
     *  @param bidID            The ID of the bid in question
     *  @return address payable The bidder address
     */
    function getBidder(uint bidID) external view returns (address payable)
    {
        return bids[bidID].bidder;
    }

    /** getWhen(uint)
     *  @dev Return the timstamp of the bid
     *  @param bidID    The ID of the bid in question
     *  @return uint    The bid timestamp
     */
    function getWhen(uint bidID) external view returns (uint)
    {
        return bids[bidID].when;
    }

    /** getRequiredPinners(uint)
     *  @dev Get the timestamp for the bid's acceptance
     *  @param bidID    The ID of the bid in question
     *  @return uint    The timestamp of the accept
     */
    function getRequiredPinners(uint bidID) external view returns (uint8)
    {
        return bids[bidID].requiredPinners;
    }

    /** getFileHash(uint)
     *  @dev Get the fileHash for the bid
     *  @param bidID    The ID of the bid in question
     *  @return bytes32 The IPFS file hash given for the bid
     */
    function getFileHash(uint bidID) external view returns (bytes32)
    {
        return bids[bidID].fileHash;
    }

    /** getFileSize(uint)
     *  @dev Get the fileSize for the bid
     *  @param bidID  The ID of the bid in question
     *  @return uint64 The file size in bytes
     */
    function getFileSize(uint bidID) external view returns (uint64)
    {
        return bids[bidID].fileSize;
    }

    /** getDuration(uint)
     *  @dev Get the requested pin duration for the bid
     *  @param bidID    The ID of the bid in question
     *  @return uint    The pin duration in seconds
     */
    function getDuration(uint bidID) external view returns (uint)
    {
        return bids[bidID].duration;
    }

    /** getBidAmount(uint)
     *  @dev Get the funds to be paid to the pinners
     *  @param bidID    The ID of the bid in question
     *  @return uint    The amount of Ether to be paid to the pinners
     */
    function getBidAmount(uint bidID) external view returns (uint)
    {
        return bids[bidID].bidAmount;
    }

    /** getBid(uint)
     *  @dev Get the primary attributes of a Bid
     *  @param bidID    The ID of the bid in question
     *  @return address Address of the bidder
     *  @return bytes32 IPFS File hash
     *  @return uint     File size in bytes
     *  @return uint    The amount of the bid in wei
     *  @return uint    The duration in seconds for the pin
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
        return(
            bids[bidID].bidder,
            bids[bidID].fileHash,
            bids[bidID].fileSize,
            bids[bidID].bidAmount,
            bids[bidID].duration,
            bids[bidID].requiredPinners
        );
    }

    /** bidExists(uint)
     *  @dev Does a bid exist at this ID?
     *  @param bidID    The ID of the bid in question
     *  @return bool    Does it exist?
     */
    function bidExists(uint bidID) public view returns (bool)
    {
        if (bids[bidID].bidder == address(0))
        {
            return false;
        }
        return true;
    }

    /** pinnerExists(uint, address payable)
     *  @dev Does a pinner exist for this bid ID?
     *  @param bidID    The ID of the bid in question
     *  @param pinner   The address of the pinner to look for
     *  @return bool    Does it exist?
     */
    function pinnerExists(uint bidID, address payable pinner) public view returns (bool)
    {
        for (uint i = 0; i < bids[bidID].pinners.length; i++)
        {
            if (bids[bidID].pinners[i] == pinner)
            {
                return true;
            }
        }
        return false;
    }

    /** getPinnerIndex(uint, address)
     *  @dev Get the index for a pinner
     *  @param bidID    The ID of the bid in question
     *  @param pinner   The address of the pinner to look for
     *  @return uint    The index of the pinner, or -1 if not found
     */
    function getPinnerIndex(uint bidID, address pinner) public view returns (uint)
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

    /** setNextBidID(uint)
     *  @dev Set the nextBidID sequence.  WARNING: This is for emergencies!
     *  @param _nextBidID The new nextBidID value
     */
    function setNextBidID(uint _nextBidID) public ownerOnly
    {
        nextBidID = _nextBidID;
    }

}