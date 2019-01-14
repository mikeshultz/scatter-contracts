pragma solidity >=0.4.0 <0.6.0;

interface ISkatterRouter {
    function get(bytes32 _name) external view returns (address);
    function set(bytes32 _name, address _target) external;
}