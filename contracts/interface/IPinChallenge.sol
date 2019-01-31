pragma solidity >=0.5.2 <0.6.0;


/* IPinChallenge
@title Contract for handling pin challenges
@author Mike Shultz <mike@mikeshultz.com>

Ref: https://github.com/mikeshultz/scatter-contracts/docs/protocol.md
*/
interface IPinChallenge {
    /** challenge(uint)
     *  @notice Challenge a bid
     *  @param bidID    The ID of the bid to challenge
     *  @return uint     The Challenge ID
     */
    function challenge(uint bidID) external returns (uint);

    /** defend(uint)
     *  @notice Challenge a bid
     *  @param challengeID  The ID of the challenge the defend against
     *  @return uint         The newly created Defense ID
     */
    function defend(uint challengeID, bytes16 halfHashA, bytes16 halfHashB, uint8 v, bytes32 r,
                    bytes32 s)
    external returns (uint);

    /** hasOpenChallenge(uint)
     *  @notice Does the bid have an open challenge
     *  @param bidID    The ID of the bid to check
     *  @return bool    Is there an open challenge?
     */
    function hasOpenChallenge(uint bidID) external view returns (bool);

}
