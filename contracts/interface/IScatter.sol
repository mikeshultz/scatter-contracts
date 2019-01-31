pragma solidity >=0.4.0 <0.6.0;


interface IScatter {

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

    function bid(
        bytes32 fileHash,
        uint fileSize,
        uint durationSeconds,
        uint bidValue,
        uint validationPool,
        uint minValidations
    )
    external
    payable
    returns (bool);

    function bid(
        bytes32 fileHash,
        uint fileSize,
        uint duration,
        uint bidValue,
        uint validationPool
    )
    external
    payable
    returns (bool);

    function stake(uint bidId) external payable returns (bool);
    function pinned(uint bidId) external returns (bool);
    function challenge() external returns (bool);
    function defend() external returns (bool);
    function transfer(address payable _dest) external;
    function withdraw() external;

    /** burnStakes(uint)
     *  @notice Burn all stakes for a challenge
     *  @param challengeID  The Challenge ID
     *  @return bull        Success?
     */
    function burnStakes(uint challengeID) external returns (bool);

    function getBid(uint bidId) external view returns (
        address,
        bytes32,
        uint,
        uint,
        uint,
        uint,
        uint16
    );
    function getJob() external view returns (uint, bytes32, uint);
    function getBidCount() external view returns (uint);
    function getHoster(uint bidId) external view returns (address);
    function getValidation(uint bidId, uint idx) external view returns (uint, address, bool, bool);
    function getValidationCount(uint bidId) external view returns (uint);

    function isBidOpenForAccept(uint bidId) external view returns (bool);
    function isBidOpenForPin(uint bidId) external view returns (bool);
    function validationSway(uint bidId) external view returns (uint);
    function satisfied(uint bidId) external view returns (bool);

    function balance(address _address) external view returns (uint);
    function balance() external view returns (uint);

}
