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

    function addChallenge(int bidId, address payable _challenger)
        external returns (bool);

    function addDefense(int bidId, address payable _defender, 
        bytes32 uniqueHash, uint8 v, bytes32 r, bytes32 s)
    external returns (bool);

    function getChallenge(int bidId, uint idx)
    external view returns (int, uint, address payable);

}
