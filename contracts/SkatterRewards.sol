pragma solidity ^0.4.25;

import './SafeMath.sol';

library SkatterRewards {
    using SafeMath for uint;

    function getSplitAndRemainder(uint poolValue, uint validationCount)
    public pure
    returns (uint, uint)
    {
        return (
            poolValue.div(validationCount),
            poolValue.mod(validationCount)
        );
    }

}