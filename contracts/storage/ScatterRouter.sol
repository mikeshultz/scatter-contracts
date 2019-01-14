pragma solidity >=0.5.0 <0.6.0;

import '../lib/Owned.sol';
import '../interface/IScatterRouter.sol';

contract ScatterRouter is Owned, IScatterRouter {

    mapping(bytes32 => address) records;

    constructor() public {
        records[keccak256('ScatterRouter')] = address(this);
    }

    function get(bytes32 _name) external view returns (address)
    {
        return records[_name];
    }

    function set(bytes32 _name, address _target) external ownerOnly
    {
        records[_name] = _target;
    }

}