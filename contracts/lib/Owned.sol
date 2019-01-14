pragma solidity >0.4.99 <0.6.0;

contract Owned {

    address payable public owner;

    modifier ownerOnly() { require(msg.sender == owner, "denied"); _; }
    
    constructor() public { owner = msg.sender; }

    function setOwner(address payable _owner) public ownerOnly
    {
        require(_owner != address(0), "invalid address");
        require(_owner != owner, "already owner");
        owner = _owner;
    }

}