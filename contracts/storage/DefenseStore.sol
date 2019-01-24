pragma solidity ^0.5.2;

import "../lib/Owned.sol";
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
contract DefenseStore is Owned {  /// Interface: IDefenseStore
    using SafeMath for uint;

    int public defenseCount;
    mapping(int => Structures.Defense) private defenses;
    address public scatterAddress;
    IRouter public router;

    modifier scatterOnly() {
        require(msg.sender == scatterAddress, "not allowed");
        _;
    }

    bytes32 private constant SCATTER_HASH = keccak256("Scatter");

    /** constructor(address)
     *  @dev initialize the contract
     *  @param  _router    The address of the Router contract
     */
    constructor(address _router) public {
        router = IRouter(_router);
        updateReferences();
    }

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
    external scatterOnly returns (int)
    {
        // If they've already defended, well...
        int defenseID = defenseCount;

        // Verify the signature is actually valid
        require(SLib.verifySignature(defender, uniqueHash, v, r, s), "invalid sig");

        Structures.Defense memory defense = Structures.Defense(
            bidID,
            challengeID,
            defenseID,
            now,
            defender,
            uniqueHash,
            v,
            r,
            s
        );

        defenses[defenseID] = defense;

        defenseCount += 1;

        return defenseID;
    }

    /** getDefenseCount()
     *  @dev Return the total Defenses stored
     *  @return uint    The count of challenges
     */
    function getDefenseCount() external view returns (int)
    {
        return defenseCount;
    }

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
    function getDefense(int defenseID)
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
    )
    {

        // solhint-disable-next-line max-line-length
        Structures.Defense memory defense = defenses[defenseID];

        return (
            defense.bidID,
            defense.challengeID,
            defense.defenseID,
            defense.when,
            defense.pinner,
            defense.uniqueHash,
            defense.v,
            defense.r,
            defense.s
        );
    }

    function hashBytes32(bytes32 toHash) external pure returns (bytes32)
    {
        return SLib.hashBytes32(toHash);
    }

    function verifySignature(address signer, bytes32 hash, uint8 v, bytes32 r,
        bytes32 s)
    external pure returns (bool)
    {
        return SLib.verifySignature(signer, hash, v, r, s);
    }

    /** defenseExists(int)
     *  @dev Return a challenge for a bid
     *  @param defenseID The ID of the Defense to look for
     *  @return bool            If the Defense exists
     */
    function defenseExists(int defenseID)
    public view returns (bool)
    {
        return defenses[defenseID].when > 0;
    }

    /** setSkatter(address)
     *  @dev Using the router, update all the addresses
     *  @return bool If anything was updated
     */
    function setScatter(address newScatterAddress) public ownerOnly
    {
        assert(newScatterAddress != address(0));
        scatterAddress = newScatterAddress;
    }

    /** updateReferences()
     *  @dev Using the router, update all the addresses
     *  @return bool If anything was updated
     */
    function updateReferences() public ownerOnly returns (bool)
    {
        bool updated = false;
        address newScatterAddress = router.get(SCATTER_HASH);
        if (newScatterAddress != scatterAddress)
        {
            scatterAddress = newScatterAddress;
            updated = true;
        }
        return updated;
    }
}
