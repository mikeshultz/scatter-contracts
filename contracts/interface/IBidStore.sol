pragma solidity >=0.4.0 <0.6.0;


interface IBidStore {

    function addBid(address payable _sender, bytes32 fileHash, int64 fileSize, uint bidValue,
                    uint validationPool, int16 minValidations, uint durationSeconds)
        external returns (int);

    function addValidation(int bidId, address payable _validator, bool _isValid)
        external returns (bool);

    function getBidCount() external view returns (int);
    function getBid(int bidId) external view returns (
        address,    // bidder
        bytes32,    // fileHash
        int,      // fileSize
        uint,       // bidAmount
        uint,       // validationPool
        uint,       // duration
        int16       // minValidations
    );
    function isPinned(int bidId) external view returns (bool);
    function getPinned(int bidId) external view returns (uint);
    function getBidder(int bidId) external view returns (address payable);
    function getAccepted(int bidId) external view returns (uint);
    function getHoster(int bidId) external view returns (address);
    function getFileHash(int bidId) external view returns (bytes32);
    function getFileSize(int bidId) external view returns (int64);
    function getDuration(int bidId) external view returns (uint);
    function getValidationPool(int bidId) external view returns (uint);
    function getBidAmount(int bidId) external view returns (uint);
    function getMinValidations(int bidId) external view returns (int16);
    function getValidatorIndex(int bidId, address payable _validator) external view returns (uint);
    function getValidator(int bidId, uint idx) external view returns (address payable);
    function getValidationCount(int bidId) external view returns (uint);
    function getValidation(int bidId, uint idx) external view returns (
        uint,       // when
        address,    // validator
        bool,       // isValid
        bool        // paid
    );
    function getValidationIsValid(int bidId, uint idx) external view returns (bool);

    function setHoster(int bidId, address payable hoster) external returns (bool);
    function setAcceptNow(int bidId, address payable hoster) external returns (bool);
    function setPinned(int bidId, address payable hoster) external returns (bool);
    function setHosterPaid(int bidId) external returns (bool);
    function setValidatorPaid(int bidId, uint idx) external returns (bool);

}