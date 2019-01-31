pragma solidity ^0.5.2;

import "../lib/Owned.sol";
import "../lib/Structures.sol";
import "../interface/IRouter.sol";


/* IPinStake
 * @title The interface for the staking storage contract
 * @dev This contract is only intended to be used by the Scatter contract.
 * @author Mike Shultz <mike@mikeshultz.com>
 */
interface IPinStake {

    /** addStake(int, uint, address payable)
     *  @dev add a Stake to a bid
     *  @param bidId    The ID of the bid
     *  @param _value    The value staked
     *  @param staker   The staker account
     */
    function addStake(uint bidId, uint _value, address payable staker)
    external returns (bool);

    /** addStakeValue(uint, uint, address payable)
     *  @dev add a Stake to a bid
     *  @param bidId    The ID of the bid
     *  @param _value    The value staked
     *  @param staker   The staker account
     */
    function addStakeValue(uint bidId, uint _value, address payable staker)
    external returns (bool);

    /** removeStake(uint, address payable)
     *  @dev remove a Stake from a bid
     *  @param bidId    The ID of the bid
     *  @param staker   The staker account
     */
    function removeStake(uint bidId, address payable staker)
    external returns (bool);

    /** burnStakes(uint)
     *  @dev burn everyone's stake for a bid
     *  @param bidID    The ID of the bid
     *  @return bool    Success?
     */
    function burnStakes(uint bidID)
    external returns (bool);

    /** getStakeValue(uint, address payable)
     *  @dev Get a staker's value
     *  @param bidId    The ID of the bid
     *  @param staker   The staker account
     *  @return uint    The value staked
     */
    function getStakeValue(uint bidId, address payable staker)
    external view returns (uint);

    /** getStakeNonce(uint)
     *  @dev Get the nonce for the stake
     *  @param bidId    The ID of the bid
     *  @return uint    The nonce of the stake for that bid
     */
    function getStakeNonce(uint bidId, address payable staker)
    external view returns (uint8);

    /** getStakeCount(uint)
     *  @dev Get the amount of stakes for a bid
     *  @param bidId    The ID of the bid
     *  @return uint    The value staked
     */
    function getStakeCount(uint bidId)
    external view returns (uint);

    /** getStakerIndex(uint, address payable)
     *  @dev add a Stake to a bid
     *  @param bidId    The ID of the bid
     *  @param staker   The staker account
     */
    function getStakerIndex(uint bidId, address payable staker)
    external view returns (uint);

}