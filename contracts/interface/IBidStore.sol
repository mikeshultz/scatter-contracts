pragma solidity >=0.4.0 <0.6.0;


interface IBidStore {

    function addBid(address payable _sender, bytes32 fileHash, int64 fileSize, uint bidValue,
                    uint durationSeconds, int8 requiredPinners)
        external returns (int);

    function addChallenge(int bidId, address payable _validator) external returns (bool);

    function setPinned(int bidId, address payable pinner) external returns (bool);
    function setValidatorPaid(int bidId, uint idx) external returns (bool);

    function getBid(int bidId) external view returns (
        address,    // bidder
        bytes32,    // fileHash
        int,        // fileSize 
        uint,       // bidAmount
        uint,       // duration
        int8        // requiredPinners
    );

    function getBidCount() external view returns (int);
    function isPinned(int bidId) external view returns (bool);
    function getPinned(int bidId) external view returns (uint);
    function getBidder(int bidId) external view returns (address payable);
    function getRequiredPinners(int bidId) external view returns (uint);
    function getFileHash(int bidId) external view returns (bytes32);
    function getFileSize(int bidId) external view returns (int64);
    function getDuration(int bidId) external view returns (uint);
    function getBidAmount(int bidId) external view returns (uint);
    function bidExists(int bidId) external view returns (bool);
    function getPinnerIndex(int bidID, address pinner) external view returns (address);

}