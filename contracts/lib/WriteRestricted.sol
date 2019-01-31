pragma solidity >0.4.99 <0.6.0;

import "./Owned.sol";


/** WriteRestricted
 * @title Provieds simple write restriction for calls
 * @author Mike Shultz <mike@mikeshultz.com>
 */
contract WriteRestricted is Owned {

    mapping (address => bool) public writers;

    modifier writersOnly() {
        require(writers[msg.sender], "not writer");
        _;
    }

    constructor() public
    {
        // Set deployer as writer
        writers[msg.sender] = true;
    }

    /** isWriter(address)
     * @notice check if an address is a writer
     * @param _writer   The address to grant write perms
     * @return bool     Allowed to write?
     */
    function isWriter(address _writer) external view returns (bool)
    {
        return writers[_writer];
    }

    /** grant(address)
     * @notice Grant write rights to the address
     * @param _writer   The address to grant write perms
     */
    function grant(address _writer) public ownerOnly
    {
        require(_writer != address(0), "invalid address");
        require(!writers[_writer], "already writer");
        setWriter(_writer, true);
    }

    /** revoke(address)
     * @notice Revoke write rights
     * @param _writer   The address to revoke write perms from
     */
    function revoke(address _writer) public ownerOnly
    {
        require(_writer != address(0), "invalid address");
        require(writers[_writer], "not writer");
        setWriter(_writer, false);
    }

    /** setWriter(address, bool)
     * @notice Set writer value
     * @param _writer   The address to grant write perms
     * @param canWrite  If the addrress is allowed to write
     */
    function setWriter(address _writer, bool canWrite) internal
    {
        writers[_writer] = canWrite;
    }

}
