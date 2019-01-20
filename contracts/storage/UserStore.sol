pragma solidity >=0.5.2 <0.6.0;

import "../lib/Owned.sol";
import "../lib/HashStore.sol";


contract UserStore is HashStore, Owned {

    address public writer;

    modifier accessControl() { require(msg.sender == writer, "denied"); _; }

    constructor() public
    {
        setWriter(msg.sender);
    }

    function setWriter(address _writer) public ownerOnly
    {
        require(_writer != address(0), "zero address");
        writer = _writer;
    }

}
