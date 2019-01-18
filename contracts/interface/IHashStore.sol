pragma solidity >=0.5.2 <0.6.0;

import "../lib/Owned.sol";


interface IHashStore {

    function setWriter(address _writer) external;

    function setString(bytes32 _hash, string calldata _value) external;
    function setUint(bytes32 _hash, uint _value) external;
    function setBytes32(bytes32 _hash, bytes32 _value) external;

    function getString(bytes32 _hash) external view returns (string memory);
    function getUint(bytes32 _hash) external view returns (uint);
    function getBytes32(bytes32 _hash) external view returns (bytes32);

}
