pragma solidity ^0.5.2;

import "../lib/Owned.sol";
import "../lib/Structures.sol";
import "../lib/SafeMath.sol";
import "../lib/SLib.sol";
import "../interface/IChallengeStore.sol";
import "../interface/IRouter.sol";


/* ChallengeStore
 * @title The primary persistance contract for storing Challenges.
 * @dev This contract is only intended to be used by the Scatter contract.
 * @author Mike Shultz <mike@mikeshultz.com>
 */
contract ChallengeStore is Owned {
    using SafeMath for uint;

    int public challengeCount;
    mapping(int => Structures.Challenge) private challenges;
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

    /** addChallenge(int, address payable)
     *  @dev Add a challenge for a bid
     *  @param  bidID       The ID of the bid to challenge
     *  @param  challenger  The address of the validator
     *  @return int         The new Challenge ID
     */
    function addChallenge(int bidID, address payable challenger)
    external scatterOnly returns (int)
    {
        /*Structures.Challenge memory chal = Structures.Challenge(
            bidID,      // bidID
            now,        // when
            _challenger // challenger
        );

        challenges[bidID].push(chal);*/

        int challengeID = challengeCount;

        challenges[challengeID].bidID = bidID;
        challenges[challengeID].when = now;
        challenges[challengeID].challenger = challenger;

        challengeCount += 1;

        return challengeID;
    }

    /** getChallengeCount(int)
     *  @dev Return the total challenges for a bid
     *  @return uint    The count of challenges
     */
    function getChallengeCount() external view returns (int)
    {
        return challengeCount;
    }

    /** getChallenge(int)
     *  @dev Return a challenge for a bid
     *  @param challengeID          The ID of the Challenge
     *  @return int                 The bidID the Challenge is associated with
     *  @return uint                Timestamp of the Challenge
     *  @return address payable     The challenger's address
     */
    function getChallenge(int challengeID) external view returns (int, uint, address payable)
    {
        return (
            challenges[challengeID].bidID,
            challenges[challengeID].when,
            challenges[challengeID].challenger
        );
    }

    /** challengeExists(int)
     *  @dev Check if a challenge exists
     *  @param challengeID  The ID of the Challenge
     *  @return bool        If the Challenge exists
     */
    function challengeExists(int challengeID)
    public view returns (bool)
    {
        return challenges[challengeID].when > 0;
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
