pragma solidity >=0.5.0 <0.6.0;

import "../lib/Owned.sol";
import "../interface/IRouter.sol";


contract Router is Owned, IRouter {

    mapping(bytes32 => address) private records;

    constructor() public {
        records[keccak256("ScatterRouter")] = address(this);
    }

    function set(bytes32 _name, address _target) external ownerOnly
    {
        records[_name] = _target;
    }

    function get(bytes32 _name) external view returns (address)
    {
        return records[_name];
    }

}
