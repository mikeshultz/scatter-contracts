pragma solidity ^0.5.2;

import "../lib/Owned.sol";
import "../lib/Structures.sol";
import "../interface/IRouter.sol";


/* IChallengeStore
 * @title The interface for the ChallengeStore contract
 * @dev This contract is only intended to be used by the Scatter contract.
 * @author Mike Shultz <mike@mikeshultz.com>
 */
interface IChallengeStore {

    function addChallenge(uint bidId, address payable _challenger)
        external returns (uint);

    /** addDefense(uint)
     *  @dev Add a Defense ID to the Challenge
     *  @param challengeID  The ID of the Challenge
     *  @param defenseID    The ID of the Defense
     *  @return bool        Success?
     */
    function addDefense(uint challengeID, uint defenseID) external returns (bool);

    function getChallenge(uint bidId, uint idx)
    external view returns (uint, uint, address payable);

    /** getBidID(uint)
     *  @dev Return the bidID associated with the Challenge
     *  @param challengeID          The ID of the Challenge
     *  @return uint                 The bidID the Challenge is associated with
     */
    function getBidID(uint challengeID) external view returns (uint);

    /** getWhen(uint)
     *  @dev Return the timestamp a challenge was made
     *  @param challengeID          The ID of the Challenge
     *  @return uint                 The bidID the Challenge is associated with
     */
    function getWhen(uint challengeID) external view returns (uint);

    /** getChallenger(uint)
     *  @dev Return the account that created the Challenge
     *  @param challengeID          The ID of the Challenge
     *  @return uint                 The bidID the Challenge is associated with
     */
    function getChallenger(uint challengeID) external view returns (address);

    /** getWhen(uint)
     *  @dev Return if the Challenge has been fully defended
     *  @param challengeID  The ID of the Challenge
     *  @return bool        If the challenge has been fully defended
     */
    function getDefended(uint challengeID) external view returns (bool);

    /** getDefenseCount(uint)
     *  @dev Return the current amount of defenses known for this Challenge
     *  @param challengeID  The ID of the Challenge
     *  @return uint        Total defenses
     */
    function getDefenseCount(uint challengeID) external view returns (uint);

    /** getDefenseCount(uint)
     *  @dev Return the current amount of defenses known for this Challenge
     *  @param challengeID  The ID of the Challenge
     *  @return uint        Total defenses
     */
    function getDefenseID(uint challengeID, uint index) external view returns (uint);

    /** challengeExists(uint)
     *  @dev Check if a challenge exists
     *  @param challengeID  The ID of the Challenge
     *  @return bool        If the Challenge exists
     */
    function challengeExists(uint challengeID) external view returns (bool);

}
