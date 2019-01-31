pragma solidity ^0.5.2;

import "../lib/Owned.sol";
import "../lib/WriteRestricted.sol";
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
contract ChallengeStore is Owned, WriteRestricted {
    using SafeMath for uint;

    bytes32 private constant SCATTER_HASH = keccak256("Scatter");
    bytes32 private constant PIN_CHALLENGE_HASH = keccak256("PinChallenge");

    uint public nextChallengeID;
    mapping(uint => Structures.Challenge) private challenges;

    /** constructor(address)
     *  @dev initialize the contract
     */
    constructor() public
    {
        nextChallengeID = 1;
    }

    /** addChallenge(uint, address payable)
     *  @dev Add a challenge for a bid
     *  @param  bidID       The ID of the bid to challenge
     *  @param  challenger  The address of the validator
     *  @return uint         The new Challenge ID
     */
    function addChallenge(uint bidID, address payable challenger)
    external writersOnly returns (uint)
    {
        /*Structures.Challenge memory chal = Structures.Challenge(
            bidID,      // bidID
            now,        // when
            _challenger // challenger
        );

        challenges[bidID].push(chal);*/

        uint challengeID = nextChallengeID;

        challenges[challengeID].bidID = bidID;
        challenges[challengeID].when = now;
        challenges[challengeID].challenger = challenger;

        nextChallengeID += 1;

        return challengeID;
    }

    /** addDefense(uint)
     *  @dev Add a Defense ID to the Challenge
     *  @param challengeID  The ID of the Challenge
     *  @param defenseID    The ID of the Defense
     *  @return bool        Success?
     */
    function addDefense(uint challengeID, uint defenseID) external writersOnly returns (bool)
    {
        challenges[challengeID].defenses.push(defenseID);
        return true;
    }

    /** getChallengeCount(uint)
     *  @dev Return the total challenges for a bid
     *  @return uint    The count of challenges
     */
    function getChallengeCount() external view returns (uint)
    {
        return nextChallengeID - 1;
    }

    /** getChallenge(uint)
     *  @dev Return a challenge for a bid
     *  @param challengeID          The ID of the Challenge
     *  @return uint                 The bidID the Challenge is associated with
     *  @return uint                Timestamp of the Challenge
     *  @return address payable     The challenger's address
     */
    function getChallenge(uint challengeID) external view returns (uint, uint, address payable)
    {
        return (
            challenges[challengeID].bidID,
            challenges[challengeID].when,
            challenges[challengeID].challenger
        );
    }

    /** getBidID(uint)
     *  @dev Return the bidID associated with the Challenge
     *  @param challengeID          The ID of the Challenge
     *  @return uint                 The bidID the Challenge is associated with
     */
    function getBidID(uint challengeID) external view returns (uint)
    {
        return challenges[challengeID].bidID;
    }

    /** getWhen(uint)
     *  @dev Return the timestamp a challenge was made
     *  @param challengeID          The ID of the Challenge
     *  @return uint                 The bidID the Challenge is associated with
     */
    function getWhen(uint challengeID) external view returns (uint)
    {
        return challenges[challengeID].when;
    }

    /** getChallenger(uint)
     *  @dev Return the account that created the Challenge
     *  @param challengeID          The ID of the Challenge
     *  @return uint                 The bidID the Challenge is associated with
     */
    function getChallenger(uint challengeID) external view returns (address)
    {
        return challenges[challengeID].challenger;
    }

    /** getWhen(uint)
     *  @dev Return if the Challenge has been fully defended
     *  @param challengeID  The ID of the Challenge
     *  @return bool        If the challenge has been fully defended
     */
    function getDefended(uint challengeID) external view returns (bool)
    {
        return challenges[challengeID].defended;
    }

    /** getDefenseCount(uint)
     *  @dev Return the current amount of defenses known for this Challenge
     *  @param challengeID  The ID of the Challenge
     *  @return uint        Total defenses
     */
    function getDefenseCount(uint challengeID) external view returns (uint)
    {
        return challenges[challengeID].defenses.length;
    }

    /** getDefenseCount(uint)
     *  @dev Return the current amount of defenses known for this Challenge
     *  @param challengeID  The ID of the Challenge
     *  @return uint        Total defenses
     */
    function getDefenseID(uint challengeID, uint index) external view returns (uint)
    {
        return challenges[challengeID].defenses[index];
    }

    /** challengeExists(uint)
     *  @dev Check if a challenge exists
     *  @param challengeID  The ID of the Challenge
     *  @return bool        If the Challenge exists
     */
    function challengeExists(uint challengeID)
    public view returns (bool)
    {
        return challenges[challengeID].when > 0;
    }

}
