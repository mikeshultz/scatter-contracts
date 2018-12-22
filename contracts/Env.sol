pragma solidity ^0.4.25;


contract Env {

    address owner;
    mapping (string => string) var_strings;
    mapping (string => uint32) var_uints;
    mapping (address => bool) banned;

    modifier ownerOnly() { require(msg.sender == owner, "denied"); _; }

    constructor() public
    {
        owner = msg.sender;

        // Presets
        var_uints["minBid"] = 0;
        var_uints["defaultMinValidations"] = 2;
        var_uints["minDuration"] = 1 weeks;
        var_uints["acceptHoldDuration"] = 15 minutes;

        banned[0x0000000000000000000000000000000000000000] = true;
    }

    function setstr(string key, string value) public ownerOnly
    {
        var_strings[key] = value;
    }

    function getstr(string key) public view returns (string)
    {
        return var_strings[key];
    }

    function setuint(string key, uint32 value) public ownerOnly
    {
        var_uints[key] = value;
    }

    function getuint(string key) public view returns (uint32)
    {
        return var_uints[key];
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