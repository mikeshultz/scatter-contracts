pragma solidity ^0.5.2;

import "../lib/Owned.sol";
import "../lib/WriteRestricted.sol";
import "../lib/Structures.sol";
import "../lib/SafeMath.sol";
import "../interface/IRouter.sol";


/* BidStore
 * @title The staking storage contract
 * @dev This contract is only intended to be used by the Scatter contract.
 * @author Mike Shultz <mike@mikeshultz.com>
 */
contract PinStake is Owned, WriteRestricted {
    using SafeMath for uint;

    mapping(uint => Structures.Stake[]) private stakes;

    bytes32 private constant SCATTER_HASH = keccak256("Scatter");

    /** addStake(uint, uint, address payable)
     *  @dev add a Stake to a bid
     *  @param bidID    The ID of the bid
     *  @param _value    The value staked
     *  @param staker   The staker account
     *  @return bool    Succeeded?
     */
    function addStake(uint bidID, uint _value, address payable staker)
    external writersOnly returns (bool)
    {
        uint8 nonce = uint8(getStakeCount(bidID) + 1);
        Structures.Stake memory newStake = Structures.Stake(bidID, nonce, now, _value, staker);
        stakes[bidID].push(newStake);
        return true;
    }

    /** addStakeValue(uint, uint, address payable)
     *  @dev add a Stake to a bid
     *  @param bidID    The ID of the bid
     *  @param _value    The value staked
     *  @param staker   The staker account
     *  @return bool    Succeeded?
     */
    function addStakeValue(uint bidID, uint _value, address payable staker)
    external writersOnly returns (bool)
    {
        if (!stakerExists(bidID, staker))
        {
            return false;
        }

        uint stakerIndex = getStakerIndex(bidID, staker);
        stakes[bidID][stakerIndex].value = stakes[bidID][stakerIndex].value.add(_value);

        return true;
    }

    /** removeStake(uint, address payable)
     *  @dev remove a Stake from a bid
     *  @param bidID    The ID of the bid
     *  @param staker   The staker account
     */
    function removeStake(uint bidID, address payable staker)
    external writersOnly returns (bool)
    {
        if (stakes[bidID].length < 1)
        {
            return false;
        }

        if (!stakerExists(bidID, staker))
        {
            return false;
        }

        uint stakerIndex = getStakerIndex(bidID, staker);
        
        delete stakes[bidID][stakerIndex];

        return true;
    }

    /** removeStake(uint)
     *  @dev burn everyone's stake for a bid
     *  @param bidID    The ID of the bid
     *  @return bool    Success?
     */
    function burnStakes(uint bidID)
    external writersOnly returns (bool)
    {
        if (stakes[bidID].length < 1)
        {
            return false;
        }

        delete stakes[bidID];

        return true;
    }

    /** getStakeValue(uint, address payable)
     *  @dev Get a staker's value
     *  @param bidID    The ID of the bid
     *  @param staker   The staker account
     *  @return uint    The value staked
     */
    function getStakeValue(uint bidID, address payable staker)
    external view returns (uint)
    {
        if (getStakeCount(bidID) < 1)
        {
            return 0;
        }

        if (!stakerExists(bidID, staker))
        {
            return 0;
        }

        uint stakerIndex = getStakerIndex(bidID, staker);
        return stakes[bidID][stakerIndex].value;
    }

    /** getStakeNonce(uint)
     *  @dev Get the nonce for the stake
     *  @param bidID    The ID of the bid
     *  @return uint    The nonce of the stake for that bid
     */
    function getStakeNonce(uint bidID, address payable staker)
    external view returns (uint8)
    {
        if (getStakeCount(bidID) < 1)
        {
            return 0;
        }

        if (!stakerExists(bidID, staker))
        {
            return 0;
        }

        uint stakerIndex = getStakerIndex(bidID, staker);
        return stakes[bidID][stakerIndex].nonce;
    }

    /** getStakeCount(uint)
     *  @dev Get the amount of stakes for a bid
     *  @param bidID    The ID of the bid
     *  @return uint    The value staked
     */
    function getStakeCount(uint bidID)
    public view returns (uint)
    {
        return stakes[bidID].length;
    }

    /** stakerExists(uint, address payable)
     *  @dev Does a staker exist for a bid?
     *  @param bidID    The ID of the bid
     *  @param staker   If the staker is present
     *  @return bool    If he exists
     */
    function stakerExists(uint bidID, address payable staker)
    public view returns (bool)
    {
        for (uint i = 0; i < stakes[bidID].length; i++)
        {
            if (stakes[bidID][i].staker == staker)
            {
                return true;
            }
        }
        return false;
    }

    /** getStakerIndex(uint, address payable)
     *  @dev add a Stake to a bid
     *  @param bidID    The ID of the bid
     *  @param staker   The staker account
     */
    function getStakerIndex(uint bidID, address payable staker)
    public view returns (uint)
    {
        for (uint i = 0; i < stakes[bidID].length; i++)
        {
            if (stakes[bidID][i].staker == staker)
            {
                return i;
            }
        }
        return 0;
    }

}