pragma solidity >=0.4.0 <0.6.0;


interface IBidStore {

    function addBid(address payable _sender, bytes32 fileHash, uint64 fileSize, uint bidValue,
                    uint durationSeconds, uint8 requiredPinners)
        external returns (uint);

    function addChallenge(uint bidID, uint challengeID) external returns (bool);
    function addPinner(uint bidID, address payable pinner) external returns (bool);

    function getBid(uint bidId) external view returns (
        address,    // bidder
        bytes32,    // fileHash
        uint,        // fileSize 
        uint,       // bidAmount
        uint,       // duration
        uint8        // requiredPinners
    );

    function getBidCount() external view returns (uint);
    function isFullyPinned(uint bidID) external view returns (bool);
    function getPinnerIndex(uint bidID, address pinner) external view returns (address);
    /** pinnerExists(uint, address payable)
     *  @dev Does a pinner exist for this bid ID?
     *  @param bidID    The ID of the bid in question
     *  @param pinner   The address of the pinner to look for
     *  @return bool    Does it exist?
     */
    function pinnerExists(uint bidID, address payable pinner) external view returns (bool);
    function getPinnerCount(uint bidID) external view returns (uint);
    function getPinner(uint bidID, uint pinnerIndex) external view returns (address);

    /** getChallengeCount(uint)
     *  @dev Get the total Challenges for a bid
     *  @param bidID    The ID of the bid in question
     *  @return uint    The amount of challenges
     */
    function getChallengeCount(uint bidID) external view returns (uint);

    /** getChallengeID(uint, uint)
     *  @dev Get the timestamp for the bid's pinning
     *  @param bidID    The ID of the bid in question
     *  @param index    The array index to return
     *  @return address The pinner
     */
    function getChallengeID(uint bidID, uint index) external view returns (uint);

    function getBidder(uint bidId) external view returns (address payable);
    function getWhen(uint bidID) external view returns (uint);
    function getRequiredPinners(uint bidId) external view returns (uint8);
    function getFileHash(uint bidId) external view returns (bytes32);
    function getFileSize(uint bidId) external view returns (uint64);
    function getDuration(uint bidId) external view returns (uint);
    function getBidAmount(uint bidId) external view returns (uint);
    function bidExists(uint bidId) external view returns (bool);

}