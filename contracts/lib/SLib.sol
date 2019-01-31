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

    /** durationHasPassed(uint, uint, uint)
     * @notice Check if a duration has passed
     * @param _date     Now, or the later date
     * @param compDate  The date to compare
     * @param duration  The length of time to check if passed
     * @return bool     If the duration has passed
     */
    function durationHasPassed(uint _date, uint compDate, uint duration)
    public pure returns (bool)
    {
        uint diff = compDate - _date;
        if (diff < duration) {
            return false;
        }
        return true;
    }

    /** hashBytes32(bytes32)
     * @notice Keccak hash a bytes32 value
     * @param value     The value to hash
     * @return bytes32  The hash
     */
    function hashBytes32(bytes32 value) internal pure returns (bytes32)
    {
        return keccak256(abi.encodePacked(SIGN_PREFIX, value));
    }

    /** verifySignature(address, bytes32, uint8, bytes32, bytes32)
     * @notice Verify that a signature of a hash recovers to the signer
     * @param signer    The signing account
     * @param hash      The hash that was signed
     * @param v         Magic V of an Ethereum sig
     * @param r         Magic R
     * @param s         Magic S
     * @return bool     If the signature is valid
     */
    function verifySignature(address signer, bytes32 hash, uint8 v, bytes32 r,
        bytes32 s) internal pure returns(bool)
    {
        bytes32 prefixedHash = hashBytes32(hash);
        return ecrecover(prefixedHash, v, r, s) == signer;
    }

    /** concatBytes32(bytes16, bytes16)
     *  @notice concatenate two bytes16 vars into a bytes32
     *  @param _a  The left hand part of the return var
     *  @param _b  The right hand part of the return var
     *  @return bytes32  bytes32(_a + _b)
     */
    function concatBytes32(bytes16 _a, bytes16 _b) internal pure returns (bytes32 out)
    {
        assembly {
            // Get working memory pointer
            let st := mload(0x40)
            // Add _a to the start of the word
            mstore(st, _a)
            // Add _b to the second half of the word
            mstore(add(st, 0x10), _b)
            // Store the word to out
            out := mload(st)
        }
    }

}
