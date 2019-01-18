pragma solidity >=0.5.2 <0.6.0;

import "../lib/Owned.sol";
import "./IHashStore.sol";


interface IRegister {
    
    function getUserFile(address _user) external view returns (bytes32);
    function register(address _user, bytes32 ipfsUserFile) external;

}