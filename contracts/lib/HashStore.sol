pragma solidity >=0.5.2 <0.6.0;

import "../lib/Owned.sol";


contract HashStore {  /// interface: IHashStore

    mapping (bytes32 => string) public stringsStore;
    mapping (bytes32 => uint) public uintStore;
    mapping (bytes32 => bytes32) public bytes32Store;

    modifier authorizedOnly() { _; }

    function setString(bytes32 _hash, string calldata _value) external authorizedOnly
    {
        stringsStore[_hash] = _value;
    }

    function setUint(bytes32 _hash, uint _value) external authorizedOnly
    {
        uintStore[_hash] = _value;
    }

    function setBytes32(bytes32 _hash, bytes32 _value) external authorizedOnly
    {
        bytes32Store[_hash] = _value;
    }

    function getString(bytes32 _hash) external view returns (string memory)
    {
        return stringsStore[_hash];
    }

    function getUint(bytes32 _hash) external view returns (uint)
    {
        return uintStore[_hash];
    }

    function getBytes32(bytes32 _hash) external view returns (bytes32)
    {
        return bytes32Store[_hash];
    }

}
