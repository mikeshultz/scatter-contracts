pragma solidity ^0.5.2;

import './SafeMath.sol';
import './Structures.sol';
import '../interface/IBidStore.sol';

library ScatterRewards {
    using SafeMath for uint;

    uint constant MAX_UINT = 2**256 - 1;

    function getSplitAndRemainder(uint poolValue, uint validationCount)
    public pure
    returns (uint, uint)
    {
        return (
            poolValue.div(validationCount),
            poolValue.mod(validationCount)
        );
    }

    function payValidators(address _store, int bidId, mapping(address => uint) storage sheet)
    internal returns (uint)
    {
        IBidStore store = IBidStore(_store);
        uint validationPool = store.getValidationPool(bidId);
        uint validatorCount = store.getValidationCount(bidId);

        uint totalPaid = 0;
        uint split;
        uint remainder;
        (split, remainder) = getSplitAndRemainder(
            validationPool,
            validatorCount
        );

        for (uint i=0; i<validatorCount; i++)
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