pragma solidity ^0.5.2;

contract Env {

    address public owner;
    mapping (bytes32 => string) internal var_strings;
    mapping (bytes32 => uint) internal var_uints;
    mapping (address => bool) internal banned;

    modifier ownerOnly() {
        require(msg.sender == owner, "denied");
        _;
    }

    bytes32 constant ENV_ACCEPT_HOLD_DURATION = keccak256("acceptHoldDuration");
    bytes32 constant ENV_DEFAULT_MIN_VALIDATIONS = keccak256("defaultMinValidations");
    bytes32 constant ENV_MIN_DURATION = keccak256("minDuration");
    bytes32 constant ENV_MIN_BID = keccak256("minBid");

    constructor() public
    {
        owner = msg.sender;

        // Presets
        var_uints[ENV_MIN_BID] = 0;
        var_uints[ENV_DEFAULT_MIN_VALIDATIONS] = 2;
        var_uints[ENV_MIN_DURATION] = 1 weeks;
        var_uints[ENV_ACCEPT_HOLD_DURATION] = 15 minutes;

        banned[0x0000000000000000000000000000000000000000] = true;
    }

    function setstr(bytes32 keyHash, string memory value) public ownerOnly
    {
        var_strings[keyHash] = value;
    }

    function getstr(bytes32 keyHash) public view returns (string memory)
    {
        return var_strings[keyHash];
    }

    function setuint(bytes32 keyHash, uint value) public ownerOnly
    {
        var_uints[keyHash] = value;
    }

    function getuint(bytes32 keyHash) public view returns (uint)
    {
        return var_uints[keyHash];
    }

    function ban(address _addr) public ownerOnly
    {
        banned[_addr] = true;
    }

    function unban(address _addr) public ownerOnly
    {
        banned[_addr] = false;
    }

    function isBanned(address _addr) public view returns (bool)
    {
        return banned[_addr];
    }

}
