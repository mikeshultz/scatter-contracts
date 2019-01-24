pragma solidity ^0.5.2;

import "./SafeMath.sol";
import "./Structures.sol";
import "../interface/IBidStore.sol";
import "../interface/IPinStake.sol";


/** SLib
 * @title General purpose Scatter library
 * @author Mike Shultz <mike@mikeshultz.com>
 */
library SLib {
    using SafeMath for uint;

    uint private constant MAX_UINT = 2**256 - 1;
    bytes private constant SIGN_PREFIX = "\x19Ethereum Signed Message:\n32";

    function durationHasPassed(uint _date, uint compDate, uint duration)
    public pure returns (bool)
    {
        uint diff = compDate - _date;
        if (diff < duration) {
            return false;
        }
        return true;
    }

    function payPinners(address _store, address _pinStake, int bidId)
    internal pure returns (bool)
    {
        // TODO
        IBidStore store = IBidStore(_store);
        IPinStake pinStake = IPinStake(_pinStake);

        require(bidId > -1);
        require(address(store) != address(0));
        require(address(pinStake) != address(0));

        return true;
    }

    function hashBytes32(bytes32 value) internal pure returns (bytes32)
    {
        return keccak256(abi.encodePacked(SIGN_PREFIX, value));
    }

    function verifySignature(address signer, bytes32 hash, uint8 v, bytes32 r,
        bytes32 s) internal pure returns(bool)
    {

        bytes32 prefixedHash = hashBytes32(hash);
        return ecrecover(prefixedHash, v, r, s) == signer;

        //return ecrecover(hash, v, r, s) == signer;

    }

}
