pragma solidity ^0.5.2;


/* DefenseStore Interface
 * @title The primary persistance contract for storing Defenses.
 * @dev This contract is only intended to be used by the Scatter contract.
 * @author Mike Shultz <mike@mikeshultz.com>
 */
interface IDefenseStore {

    /** addDefense(uint, address payable, bool)
     *  @dev Add a challenge for a bid
     *  @param  bidID           The ID of the bid
     *  @param  challengeID     The ID of the challenge this is in response to
     *  @param  nonce           The Defender's nonce
     *  @param  defender        The address of the responding defender/pinner
     *  @param  halfHashA       The defender's half of hashA
     *  @param  halfHashB       The defender's half of hashB
     *  @param v                Magic V of an Ethereum signature
     *  @param r                Magic R
     *  @param s                Magic S
     *  @return uint             The new defense ID
     */
    function addDefense(uint bidID, uint challengeID, uint8 nonce, address payable defender, 
        bytes16 halfHashA, bytes16 halfHashB, uint8 v, bytes32 r, bytes32 s)
    external returns (uint);

    /** getDefenseCount()
     *  @dev Return the total Defenses stored
     *  @return uint    The count of challenges
     */
    function getDefenseCount() external view returns (uint);

    /** getDefense(uint, uint, uint)
     *  @dev Return the total challenges for a bid
     *  @param defenseID    The ID of the bid
     *  @return bidID           The Bid ID this is associated with
     *  @return challengeID     The Challenge ID this defense is in response to
     *  @return defenseID       This Defense's ID
     *  @return when            When the defense was made
     *  @return pinner          The pinner that sent the Defense
     *  @return uniqueHash      The unique hash from the derived chunk
     *  @return v               Magic V of an Ethereum signature
     *  @return r               Magic R
     *  @return s               Magic S
     */
    function getDefense(uint defenseID)
    external view returns (
        uint,        // bidID
        uint,        // challengeID
        uint,        // defenseID
        uint,       // when
        address payable, // pinner
        bytes32,    // uniqueHash
        uint8,      // v
        bytes32,    // r
        bytes32     // s
    );

    function getBidID(uint defenseID) external view returns (uint);
    function getChallengeID(uint defenseID) external view returns (uint);
    function getNonce(uint defenseID) external view returns (uint8);
    function getWhen(uint defenseID) external view returns (uint);
    function getPinner(uint defenseID) external view returns (address payable);
    function getHashes(uint defenseID) external view returns (bytes16, bytes16);
    function getSignature(uint defenseID) external view returns (uint8, bytes32, bytes32);

    /** defenseExists(uint)
     *  @dev Return a challenge for a bid
     *  @param defenseID The ID of the Defense to look for
     *  @return bool            If the Defense exists
     */
    function defenseExists(uint defenseID)
    external view returns (bool);

}
