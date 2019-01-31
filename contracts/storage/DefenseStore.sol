pragma solidity ^0.5.2;

import "../lib/Owned.sol";
import "../lib/WriteRestricted.sol";
import "../lib/Structures.sol";
import "../lib/SafeMath.sol";
import "../lib/SLib.sol";
import "../interface/IDefenseStore.sol";
import "../interface/IRouter.sol";


/* DefenseStore
 * @title The primary persistance contract for storing Defenses.
 * @dev This contract is only intended to be used by the Scatter contract.
 * @author Mike Shultz <mike@mikeshultz.com>
 */
contract DefenseStore is Owned, WriteRestricted {  /// Interface: IDefenseStore
    using SafeMath for uint;

    uint public nextDefenseID;
    mapping(uint => Structures.Defense) private defenses;

    bytes32 private constant SCATTER_HASH = keccak256("Scatter");

    /** constructor(address)
     *  @dev initialize the contract
     */
    constructor() public {
        nextDefenseID = 1;
    }

    /** addDefense(uint, address payable, bool)
     *  @dev Add a challenge for a bid
     *  @param  bidID           The ID of the bid
     *  @param  challengeID     The ID of the challenge this is in response to
     *  @param  nonce           The nonce for the defense
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
    external writersOnly returns (uint)
    {
        // If they've already defended, well...
        uint defenseID = nextDefenseID;

        Structures.Defense memory defense = Structures.Defense(
            bidID,
            challengeID,
            defenseID,
            nonce,
            now,
            defender,
            halfHashA,
            halfHashB,
            v,
            r,
            s
        );

        defenses[defenseID] = defense;

        nextDefenseID += 1;

        return defenseID;
    }

    /** getDefenseCount()
     *  @dev Return the total Defenses stored
     *  @return uint    The count of challenges
     */
    function getDefenseCount() external view returns (uint)
    {
        return nextDefenseID - 1;
    }

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
        uint8,      // nonce
        uint,       // when
        address payable, // pinner
        bytes16,    // halfHashA
        bytes16,    // halfHashB
        uint8,      // v
        bytes32,    // r
        bytes32     // s
    )
    {

        // solhint-disable-next-line max-line-length
        Structures.Defense memory defense = defenses[defenseID];

        return (
            defense.bidID,
            defense.challengeID,
            defense.defenseID,
            defense.nonce,
            defense.when,
            defense.pinner,
            defense.halfHashA,
            defense.halfHashB,
            defense.v,
            defense.r,
            defense.s
        );
    }

    function getBidID(uint defenseID) external view returns (uint)
    {
        return defenses[defenseID].bidID;
    }

    function getChallengeID(uint defenseID) external view returns (uint)
    {
        return defenses[defenseID].challengeID;
    }

    function getNonce(uint defenseID) external view returns (uint8)
    {
        return defenses[defenseID].nonce;
    }

    function getWhen(uint defenseID) external view returns (uint)
    {
        return defenses[defenseID].when;
    }

    function getPinner(uint defenseID) external view returns (address payable)
    {
        return defenses[defenseID].pinner;
    }

    function getHashes(uint defenseID) external view returns (bytes16, bytes16)
    {
        return (
            defenses[defenseID].halfHashA,
            defenses[defenseID].halfHashB
        );
    }

    function getSignature(uint defenseID) external view returns (uint8, bytes32, bytes32)
    {
        return (
            defenses[defenseID].v,
            defenses[defenseID].r,
            defenses[defenseID].s
        );
    }

    /** defenseExists(uint)
     *  @dev Return a challenge for a bid
     *  @param defenseID The ID of the Defense to look for
     *  @return bool            If the Defense exists
     */
    function defenseExists(uint defenseID)
    public view returns (bool)
    {
        return defenses[defenseID].when > 0;
    }
}
