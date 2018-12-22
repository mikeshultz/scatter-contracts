pragma solidity >=0.4.0 <0.6.0;

interface SkatterBidInterface {

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
        int32 indexed bidId,
        address indexed bidder,
        uint32 indexed bidValue,
        bytes32 fileHash
    );
    event BidInvalid(bytes32 indexed fileHash, string reason);
    event BidTooLow(bytes32 indexed fileHash);
    event Accepted(int32 indexed bidId, address indexed hoster);
    event AcceptWait(int32 waitLeft);
    event Pinned(int32 indexed bidId, address indexed hoster, bytes32 fileHash);
    event NotAcceptedByPinner(int32 indexed bidId, address indexed hoster);
    event DispurseFailed(int32 indexed bidId, address indexed sender);
    event ValidationOcurred(int32 indexed bidId, address indexed validator, bool indexed isValid);

    function getJob() external view returns (int32, bytes32, int32);
    function getValidation(int32 bidId, int32 idx) external view returns (int32, int32, address, bool);
    function getValidationCount(int32 bidId) external view returns (int32);

    function isBidOpen(int32 bidId) external view returns (bool);
    function validationSway(int32 bidId) external view returns (uint32);
    function satisfied(int32 bidId) external view returns (bool);

    function bid(
        bytes32 fileHash,
        int32 fileSize,
        int32 duration,
        uint32 bidValue,
        uint32 validationPool
    )
    external
    payable
    returns (bool);

    function bid(
        bytes32 fileHash,
        int32 fileSize,
        int32 durationSeconds,
        uint32 bidValue,
        uint32 validationPool,
        int32 minValidations
    )
    external
    payable
    returns (bool);

    function accept(int32 bidId) external returns (bool);
    function pinned(int32 bidId) external returns (bool);
    function validate(int32 bidId) external;
    function invalidate(int32 bidId) external;

    function dispurse(int32 bidId) external;

}
