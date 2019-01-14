pragma solidity >=0.4.0 <0.6.0;

interface IScatterBid {

    /* Are structs useful in interface?
    struct Validation {
        int32 bidId;
        int32 when;
        address verifier;
        bool isValid;
    }

    struct Bid {
        address bidder;
        bytes32 fileHash;
        int32 fileSize;
        uint32 bidAmount;
        uint32 validationPool;
        int32 duration;
        int32 accepted;
        address hoster;
        int32 pinned;
        bool paid;
        int32 minValidations;
        Validation[] validations;
    }*/

    event BidSuccessful(
        int indexed bidId,
        address indexed bidder,
        uint indexed bidValue,
        bytes32 fileHash
    );
    event BidInvalid(bytes32 indexed fileHash, string reason);
    event BidTooLow(bytes32 indexed fileHash);
    event Accepted(int indexed bidId, address indexed hoster);
    event AcceptWait(int waitLeft);
    event Pinned(int indexed bidId, address indexed hoster, bytes32 fileHash);
    event NotAcceptedByPinner(int indexed bidId, address indexed hoster);
    event ValidationOcurred(int indexed bidId, address indexed validator, bool indexed isValid);

    function getJob() external view returns (int, bytes32, int);
    function getValidation(int bidId, int idx) external view returns (uint, address, bool, bool);
    function getValidationCount(int bidId) external view returns (uint);

    function isBidOpenForAccept(int bidId) external view returns (bool);
    function isBidOpenForPin(int bidId) external view returns (bool);
    function validationSway(int bidId) external view returns (uint);
    function satisfied(int bidId) external view returns (bool);

    function balance(address _address) external view returns (uint);
    function balance() external view returns (uint);

    function bid(
        bytes32 fileHash,
        int fileSize,
        int duration,
        uint bidValue,
        uint validationPool
    )
    external
    payable
    returns (bool);

    function bid(
        bytes32 fileHash,
        int fileSize,
        int durationSeconds,
        uint bidValue,
        uint validationPool,
        int minValidations
    )
    external
    payable
    returns (bool);

    function accept(int bidId) external returns (bool);
    function pinned(int bidId) external returns (bool);
    function validate(int bidId) external;
    function invalidate(int bidId) external;
    function transfer(address payable _dest) external;
    function withdraw() external;

}
