pragma solidity ^0.5.2;


/* DefenseStore Interface
 * @title The primary persistance contract for storing Defenses.
 * @dev This contract is only intended to be used by the Scatter contract.
 * @author Mike Shultz <mike@mikeshultz.com>
 */
interface IDefenseStore {

    /** addDefense(int, address payable, bool)
     *  @dev Add a challenge for a bid
     *  @param  bidID           The ID of the bid
     *  @param  challengeID     The ID of the challenge this is in response to
     *  @param  defender        The address of the responding defender/pinner
     *  @param  uniqueHash      The uniqueHash from the derived chunk
     *  @param v                Magic V of an Ethereum signature
     *  @param r                Magic R
     *  @param s                Magic S
     *  @return int             The new defense ID
     */
    function addDefense(int bidID, int challengeID, address payable defender, 
        bytes32 uniqueHash, uint8 v, bytes32 r, bytes32 s)
    external returns (int);

    /** getDefenseCount()
     *  @dev Return the total Defenses stored
     *  @return uint    The count of challenges
     */
    function getDefenseCount() external view returns (uint);

    /** getDefense(int, uint, uint)
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
        int,        // bidID
        int,        // challengeID
        int,        // defenseID
        uint,       // when
        address payable, // pinner
        bytes32,    // uniqueHash
        uint8,      // v
        bytes32,    // r
        bytes32     // s
    );

    /** defenseExists(int)
     *  @dev Return a challenge for a bid
     *  @param defenseID The ID of the Defense to look for
     *  @return bool            If the Defense exists
     */
    function defenseExists(int defenseID)
    external view returns (bool);

}
