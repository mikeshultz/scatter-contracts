pragma solidity ^0.5.2;

import "./SafeMath.sol";
import "./Structures.sol";
import "../interface/IBidStore.sol";


library Rewards {
    using SafeMath for uint;

    uint private constant MAX_UINT = 2**256 - 1;

    function getSplitAndRemainder(uint poolValue, uint validationCount)
    public pure
    returns (uint, uint)
    {
        return (
            poolValue.div(validationCount),
            poolValue.mod(validationCount)
        );
    }

    function durationHasPassed(uint _date, uint duration) public view returns (bool)
    {
        uint diff = now - _date;
        if (diff < duration) {
            return false;
        }
        return true;
    }

    function payValidators(address _store, int bidId, mapping(address => uint) storage sheet)
    internal returns (uint)
    {
        IBidStore store = IBidStore(_store);
        uint validationPool = store.getValidationPool(bidId);
        uint validatorCount = store.getValidationCount(bidId);

        uint totalPaid = 0;
        //assert(validatorCount > 0);
        require(validatorCount > 0, "no validations");
        uint split = validationPool.div(validatorCount);

        for (uint i = 0; i < validatorCount; i++)
        {
            address payable validator = store.getValidator(bidId, i);
            require(store.setValidatorPaid(bidId, i), "set paid failed");
            sheet[validator] += split;
            totalPaid += split;
        }

        require(totalPaid <= validationPool, "invalid payouts");

        return totalPaid;
    }

    function payHoster(address _store, int bidId, mapping(address => uint) storage sheet)
    internal returns (bool)
    {
        IBidStore store = IBidStore(_store);
        uint bidAmount = store.getBidAmount(bidId);
        address hoster = store.getHoster(bidId);

        require(store.setHosterPaid(bidId), "set paid failed");
        sheet[hoster] += bidAmount;

        return true;
    }

}
