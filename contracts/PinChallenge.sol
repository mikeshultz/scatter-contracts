pragma solidity >=0.5.2 <0.6.0;
import "./lib/Owned.sol";
import "./lib/SafeMath.sol";
import "./lib/Structures.sol";
import "./lib/SLib.sol";
import "./interface/IScatter.sol";
import "./interface/IBidStore.sol";
import "./interface/IChallengeStore.sol";
import "./interface/IDefenseStore.sol";
import "./interface/IPinStake.sol";

import "./storage/Env.sol";


/* PinChallenge
@title Contract for handling pin challenges
@author Mike Shultz <mike@mikeshultz.com>

Ref: https://github.com/mikeshultz/scatter-contracts/docs/protocol.md
*/
contract PinChallenge is Owned {
    using SafeMath for uint;

    event Challenge(uint indexed challengeID, uint indexed bidID);
    event ChallengeMaxReached(uint indexed bidID, address indexed sender);
    event ChallengeTooSoon(uint indexed bidID, address indexed sender);
    event Defense(uint indexed bidID, uint indexed when, address indexed pinner);
    event DefenseFail(uint indexed bidID);

    Env public env;
    IRouter public router;
    IBidStore public bidStore;
    IChallengeStore public challengeStore;
    IDefenseStore public defenseStore;
    IPinStake public pinStake;
    IScatter public scatter;

    bytes32 private constant SCATTER_HASH = keccak256("Scatter");
    bytes32 private constant ENV_HASH = keccak256("Env");
    bytes32 private constant BID_STORE_HASH = keccak256("BidStore");
    bytes32 private constant CHALLENGE_STORE_HASH = keccak256("ChallengeStore");
    bytes32 private constant DEFENSE_STORE_HASH = keccak256("DefenseStore");
    bytes32 private constant PIN_STAKE_HASH = keccak256("PinStake");

    modifier notBanned() { require(!env.isBanned(msg.sender), "banned"); _; }

    /** constructor(address, address)
     *  @dev initialize the contract
     *  @param  _router    The address of the Router contract
     */
    constructor(address _router) public
    {
        router = IRouter(_router);
        updateReferences();
    }

    /** challenge(uint)
     *  @notice Challenge a bid
     *  @param bidID    The ID of the bid to challenge
     *  @return uint     The Challenge ID
     */
    function challenge(uint bidID) external returns (uint)
    {
        uint challengeCount = bidStore.getChallengeCount(bidID);
        if (challengeCount > 2)
        {
            emit ChallengeMaxReached(bidID, msg.sender);
            return 0;
        }
        else if (challengeCount > 0)
        {
            uint durationSeconds = bidStore.getDuration(bidID);
            uint bidStamp = bidStore.getWhen(bidID);

            /**
             * Every file is only allowed 3 challenges over the span of it's life and they need to
             * be spaced out evenly.
             */
            if (challengeCount * (durationSeconds / 3) > now - bidStamp)
            {
                emit ChallengeTooSoon(bidID, msg.sender);
                return 0;
            }
        }

        uint challengeID = challengeStore.addChallenge(bidID, msg.sender);

        require(challengeID > 0, "addChallenge failed");

        emit Challenge(challengeID, bidID);

        return challengeID;
    }

    /** defend(uint)
     *  @notice Challenge a bid
     *  @param challengeID  The ID of the challenge the defend against
     *  @return uint         The newly created Defense ID
     */
    function defend(uint challengeID, bytes16 halfHashA, bytes16 halfHashB, uint8 v, bytes32 r,
                    bytes32 s)
    external returns (uint)
    {
        require(challengeStore.challengeExists(challengeID), "challenge not found");

        uint bidID = challengeStore.getBidID(challengeID);

        require(bidStore.bidExists(bidID), "bid not found");

        uint8 nonce = pinStake.getStakeNonce(bidID, msg.sender);

        // If they're not staked, they're not a pinner
        require(nonce > 0, "no stake");

        // TODO: Revisit logic for variable required pinners
        uint8 requiredPinners = bidStore.getRequiredPinners(bidID);
        require(uint8(nonce) <= requiredPinners, "nonce too high");

        uint defeseID = defenseStore.addDefense(bidID, challengeID, nonce, msg.sender, halfHashA,
            halfHashB, v, r, s);
        require(challengeStore.addDefense(challengeID, defeseID), "addDefense failed");

        emit Defense(bidID, now, msg.sender);

        if (uint8(challengeStore.getDefenseCount(challengeID)) >= requiredPinners)
        {
            if (!verifyChallenge(challengeID))
            {
                require(scatter.burnStakes(challengeID), "burn failed");
                emit DefenseFail(bidID);
            }
        }

        return defeseID;
    }

    /** hasOpenChallenge(uint)
     *  @notice Does the bid have an open challenge
     *  @param bidID    The ID of the bid to check
     *  @return bool    Is there an open challenge?
     */
    function hasOpenChallenge(uint bidID) external view returns (bool)
    {
        uint challengeCount = bidStore.getChallengeCount(bidID);
        if (challengeCount < 1)
        {
            return false;
        }

        uint challengeID = bidStore.getChallengeID(bidID, challengeCount - 1);

        return (!challengeStore.getDefended(challengeID));
    }

    /** updateReferences()
     *  @dev Using the router, update all the addresses
     *  @return bool If anything was updated
     */
    function updateReferences() public ownerOnly returns (bool)
    {
        bool updated = false;

        address newSAddress = router.get(SCATTER_HASH);
        if (newSAddress != address(scatter))
        {
            scatter = IScatter(newSAddress);
            updated = true;
        }

        address newEnvAddress = router.get(ENV_HASH);
        if (newEnvAddress != address(env))
        {
            env = Env(newEnvAddress);
            updated = true;
        }

        address newBSAddress = router.get(BID_STORE_HASH);
        if (newBSAddress != address(bidStore))
        {
            bidStore = IBidStore(newBSAddress);
            updated = true;
        }

        address newCSAddress = router.get(CHALLENGE_STORE_HASH);
        if (newCSAddress != address(challengeStore))
        {
            challengeStore = IChallengeStore(newCSAddress);
            updated = true;
        }

        address newDSAddress = router.get(DEFENSE_STORE_HASH);
        if (newDSAddress != address(defenseStore))
        {
            defenseStore = IDefenseStore(newDSAddress);
            updated = true;
        }

        address newPSAddress = router.get(PIN_STAKE_HASH);
        if (newPSAddress != address(pinStake))
        {
            pinStake = IPinStake(newPSAddress);
            updated = true;
        }
        return updated;
    }

    function assembleHash(uint8 nonce, bytes16 firstHalf, bytes16 secondHalf) public pure
    returns (bytes32)
    {
        if (nonce == uint8(1))
        {
            return SLib.concatBytes32(firstHalf, secondHalf);
        }
        else
        {
            return SLib.concatBytes32(secondHalf, firstHalf);
        }
    }

    function verifyDefense(uint defenseID, bytes32 hash) internal view returns (bool)
    {
        uint8 nonce = defenseStore.getNonce(defenseID);
        assert(nonce > 0);
        address pinner = defenseStore.getPinner(defenseID);

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = defenseStore.getSignature(defenseID);

        return SLib.verifySignature(pinner, hash, v, r, s);
    }

    function verifyChallenge(uint challengeID) internal view returns (bool)
    {
        require(!challengeStore.getDefended(challengeID), "already defended");

        uint firstID = challengeStore.getDefenseID(challengeID, 0);
        uint secondID = challengeStore.getDefenseID(challengeID, 1);

        uint8 firstNonce = defenseStore.getNonce(firstID);

        (bytes16 firstHalfA, bytes16 firstHalfB) = defenseStore.getHashes(firstID);
        (bytes16 secondHalfA, bytes16 secondHalfB) = defenseStore.getHashes(firstID);

        bytes32 hashA = assembleHash(firstNonce, firstHalfA, secondHalfA);
        bytes32 hashB = assembleHash(firstNonce, firstHalfB, secondHalfB);

        // Each nonce needs to be ordered differently.  See protocol ref for more info
        if (firstNonce == 1)
        {
            return (
                verifyDefense(firstID, hashA)
                && verifyDefense(secondID, hashB)
            );
        }

        // firstNonce == 2
        return (
            verifyDefense(firstID, hashB)
            && verifyDefense(secondID, hashA)
        );
    }

}
