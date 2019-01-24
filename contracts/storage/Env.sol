pragma solidity ^0.5.2;

import "../lib/Owned.sol";


/* Env
 * @title Storage for environmental variables
 * @dev This contract stores env vars for the app and other contracts.  Used as reference for all
 *      parts of the system.
 * @author Mike Shultz <mike@mikeshultz.com>
 */
contract Env is Owned {

    mapping (bytes32 => string) internal varStrings;
    mapping (bytes32 => uint) internal varUints;
    mapping (address => bool) internal banned;

    bytes32 private constant ENV_MIN_DURATION = keccak256("minDuration");
    bytes32 private constant ENV_MIN_BID = keccak256("minBid");
    bytes32 private constant ENV_REQUIRED_PINNERS = keccak256("requiredPinners");

    /** constructor()
     *  @dev Initialize this contract
     */
    constructor() public
    {
        // Presets
        varUints[ENV_MIN_BID] = 0;
        varUints[ENV_REQUIRED_PINNERS] = 2;
        varUints[ENV_MIN_DURATION] = 1 weeks;

        banned[0x0000000000000000000000000000000000000000] = true;
    }

    /** setstr(bytes32, string)
     *  @dev Store a string at the hash
     *  @param  keyHash  The location to store the string
     *  @param  value    The string to store
     */
    function setstr(bytes32 keyHash, string memory value) public ownerOnly
    {
        varStrings[keyHash] = value;
    }

    /** getstr(bytes32)
     *  @dev Return the string value at the hash
     *  @param  keyHash  The location
     *  @return string   The value
     */
    function getstr(bytes32 keyHash) public view returns (string memory)
    {
        return varStrings[keyHash];
    }

    /** setuint(bytes32, uint)
     *  @dev Store a uint at the hash
     *  @param  keyHash  The location to store the uint
     *  @param  value    The uint to store
     */
    function setuint(bytes32 keyHash, uint value) public ownerOnly
    {
        varUints[keyHash] = value;
    }

    /** getuint(bytes32)
     *  @dev Return the uint value at the hash
     *  @param  keyHash  The location
     *  @return uint     The value
     */
    function getuint(bytes32 keyHash) public view returns (uint)
    {
        return varUints[keyHash];
    }

    /** ban(address)
     *  @dev Set an address as banned
     *  @param  _addr  The address to ban
     */
    function ban(address _addr) public ownerOnly
    {
        banned[_addr] = true;
    }

    /** ban(address)
     *  @dev Unban an address
     *  @param  _addr  The address to unban
     */
    function unban(address _addr) public ownerOnly
    {
        banned[_addr] = false;
    }

    /** isBanned(address)
     *  @dev Is an address set as banned?
     *  @param  _addr  The address to check
     *  @return bool   Is the address banned?
     */
    function isBanned(address _addr) public view returns (bool)
    {
        return banned[_addr];
    }

}
