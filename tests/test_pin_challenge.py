""" Tests for ChallengeStore """
import pytest
from datetime import datetime
from hexbytes import HexBytes
from eth_utils import add_0x_prefix, remove_0x_prefix
from .utils import (
    get_accounts,
    std_tx,
    normalize_filehash,
    has_event,
    get_event,
)
from .consts import (
    MAIN_CONTRACT_NAME,
    PIN_CHALLENGE_CONTRACT_NAME,
    CHALLENGE_STORE_CONTRACT_NAME,
    PIN_STAKE_CONTRACT_NAME,
    DEFENSE_STORE_CONTRACT_NAME,
    STORE_CONTRACT_NAME,
    RANDOM_HASH,
    FILE_HASH_1,
    FILE_HASH_2,
    FILE_SIZE_1,
    DURATION_1,
)


def test_assemble_hash(web3, contracts):
    """ Test assembleHash """
    owner, _, _, _, _, _, _ = get_accounts(web3)

    pinChallenge = contracts.get(PIN_CHALLENGE_CONTRACT_NAME)
    assert pinChallenge is not None, "Contract not found"

    bytes32_orig = remove_0x_prefix(FILE_HASH_1)
    bytes16_first = bytes32_orig[:32]
    bytes16_second = bytes32_orig[32:]

    bytes32_assembled = pinChallenge.functions.assembleHash(1, bytes16_first, bytes16_second).call()
    assert normalize_filehash(bytes32_assembled) == add_0x_prefix(bytes32_orig), (
        "Not assembled properly"
    )

    bytes32_assembled = pinChallenge.functions.assembleHash(2, bytes16_first, bytes16_second).call()
    assert normalize_filehash(bytes32_assembled) == add_0x_prefix(bytes16_second + bytes16_first), (
        "Nonce 2 not assembled properly"
    )


def test_challenge(web3, contracts):
    """ Test the challenge process. Basically an integration test because it leans on all storage
    """

    if web3.is_eth_tester:
        pytest.skip("eth_sign is not currently supported by eth_tester")

    owner, bidder, pinner1, pinner2, _, _, _ = get_accounts(web3)

    scatter = contracts.get(MAIN_CONTRACT_NAME)
    challenge = contracts.get(PIN_CHALLENGE_CONTRACT_NAME)
    challengeStore = contracts.get(CHALLENGE_STORE_CONTRACT_NAME)
    pinStake = contracts.get(PIN_STAKE_CONTRACT_NAME)
    defenseStore = contracts.get(DEFENSE_STORE_CONTRACT_NAME)
    bidStore = contracts.get(STORE_CONTRACT_NAME)

    assert challengeStore.functions.isWriter(scatter.address).call(), "Scatter not writer"
    assert challengeStore.functions.isWriter(challenge.address).call(), "PinChallenge not writer"
    assert pinStake.functions.isWriter(scatter.address).call(), "Scatter not writer"
    assert defenseStore.functions.isWriter(challenge.address).call(), "PinStake not writer"

    assert challenge.functions.pinStake().call() == pinStake.address, "pinStake not set."
    assert challenge.functions.defenseStore().call() == defenseStore.address, "defenseStore not set."
    assert challenge.functions.challengeStore().call() == challengeStore.address, "challengeStore not set."
    assert challenge.functions.bidStore().call() == bidStore.address, "bidStore not set."

    bidValue = web3.toWei(0.1, 'ether')

    tx_hash = scatter.functions.bid(
        FILE_HASH_1,
        FILE_SIZE_1,
        DURATION_1,
        bidValue
    ).transact(std_tx({
            'from': bidder,
            'gas': int(6e6),
            'value': bidValue
        }))
    receipt = web3.eth.waitForTransactionReceipt(tx_hash)
    assert receipt.status == 1, (
        'Bid transaction failed. Receipt: {}'.format(receipt)
    )

    assert has_event(scatter, 'BidSuccessful', receipt), (
        'BidSuccessful event not found'
    )
    evnt = get_event(scatter, 'BidSuccessful', receipt)
    bid_id = evnt.args.bidID

    stake_value = bidValue // 2

    tx_hash = scatter.functions.stake(bid_id).transact(std_tx({
            'from': pinner1,
            'gas': int(1e6),
            'value': stake_value,
        }))
    receipt = web3.eth.waitForTransactionReceipt(tx_hash)
    assert receipt.status == 1, (
        'Stake transaction failed. Receipt: {}'.format(receipt)
    )

    tx_hash = scatter.functions.pinned(bid_id).transact(std_tx({
            'from': pinner1,
            'gas': int(1e6),
        }))
    receipt = web3.eth.waitForTransactionReceipt(tx_hash)
    assert receipt.status == 1, (
        'Stake transaction failed. Receipt: {}'.format(receipt)
    )

    tx_hash = scatter.functions.stake(bid_id).transact(std_tx({
            'from': pinner2,
            'gas': int(5e6),
            'value': stake_value,
        }))
    receipt = web3.eth.waitForTransactionReceipt(tx_hash)
    assert receipt.status == 1, (
        'Stake transaction failed. Receipt: {}'.format(receipt)
    )

    tx_hash = scatter.functions.pinned(bid_id).transact(std_tx({
            'from': pinner2,
            'gas': int(6e6),
        }))
    receipt = web3.eth.waitForTransactionReceipt(tx_hash)
    assert receipt.status == 1, (
        'Stake transaction failed. Receipt: {}'.format(receipt)
    )

    assert has_event(challenge, 'Challenge', receipt), (
        'Challenge event not found'
    )
    c_evnt = get_event(challenge, 'Challenge', receipt)

    ##
    # Pinner 1 needs to defend his honor
    ##
    half_hash_a = remove_0x_prefix(FILE_HASH_1)[32:]
    half_hash_b = remove_0x_prefix(FILE_HASH_2)[32:]
    sig = web3.eth.sign(pinner1, data=HexBytes(FILE_HASH_1))
    sig = remove_0x_prefix(sig.hex())
    r = sig[:64]
    s = sig[64:128]
    v = int(sig[128:130], 16) + 27

    assert len(r) == 64  # bytes32
    assert len(s) == 64
    assert len(half_hash_a) == 32  # bytes16
    assert len(half_hash_b) == 32

    txhash = challenge.functions.defend(
        c_evnt.args.challengeID,
        half_hash_a,
        half_hash_b,
        v,
        r,
        s
    ).transact(std_tx({
        'from': pinner1,
        'gas': int(6e6),
    }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1, (
        'Stake transaction failed. Receipt: {}'.format(receipt)
    )
    assert has_event(challenge, 'Defense', receipt), (
        'Defense event not found'
    )
    d1_evnt = get_event(challenge, 'Defense', receipt)
    assert d1_evnt.args.bidID == bid_id, "Invalid bidID"
    assert d1_evnt.args.pinner == pinner1, "Invalid pinner"

    ##
    # Pinner 2 defense
    ##
    half_hash_a = remove_0x_prefix(FILE_HASH_1)[:32]
    half_hash_b = remove_0x_prefix(FILE_HASH_2)[:32]
    sig = web3.eth.sign(pinner1, data=HexBytes(FILE_HASH_2))
    sig = remove_0x_prefix(sig.hex())
    r = sig[:64]
    s = sig[64:128]
    v = int(sig[128:130], 16) + 27

    txhash = challenge.functions.defend(
        c_evnt.args.challengeID,
        half_hash_a,
        half_hash_b,
        v,
        r,
        s
    ).transact(std_tx({
        'from': pinner2,
        'gas': int(6e6),
    }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1, (
        'Stake transaction failed. Receipt: {}'.format(receipt)
    )
    assert has_event(challenge, 'Defense', receipt), (
        'Defense event not found'
    )
    d2_evnt = get_event(challenge, 'Defense', receipt)
    assert d2_evnt.args.bidID == bid_id, "Invalid bidID"
    assert d2_evnt.args.pinner == pinner2, "Invalid pinner"


def test_mad(web3, contracts):
    """ Test the Mutually Assured Destruction mechanic
    """

    if web3.is_eth_tester:
        pytest.skip("eth_sign is not currently supported by eth_tester")

    owner, bidder, pinner1, pinner2, _, _, _ = get_accounts(web3)

    scatter = contracts.get(MAIN_CONTRACT_NAME)
    challenge = contracts.get(PIN_CHALLENGE_CONTRACT_NAME)
    challengeStore = contracts.get(CHALLENGE_STORE_CONTRACT_NAME)
    pinStake = contracts.get(PIN_STAKE_CONTRACT_NAME)
    defenseStore = contracts.get(DEFENSE_STORE_CONTRACT_NAME)
    bidStore = contracts.get(STORE_CONTRACT_NAME)

    bidValue = web3.toWei(0.1, 'ether')

    tx_hash = scatter.functions.bid(
        FILE_HASH_1,
        FILE_SIZE_1,
        DURATION_1,
        bidValue
    ).transact(std_tx({
            'from': bidder,
            'gas': int(6e6),
            'value': bidValue
        }))
    receipt = web3.eth.waitForTransactionReceipt(tx_hash)
    assert receipt.status == 1, (
        'Bid transaction failed. Receipt: {}'.format(receipt)
    )

    assert has_event(scatter, 'BidSuccessful', receipt), (
        'BidSuccessful event not found'
    )
    evnt = get_event(scatter, 'BidSuccessful', receipt)
    bid_id = evnt.args.bidID

    stake_value = bidValue // 2

    tx_hash = scatter.functions.stake(bid_id).transact(std_tx({
            'from': pinner1,
            'gas': int(1e6),
            'value': stake_value,
        }))
    receipt = web3.eth.waitForTransactionReceipt(tx_hash)
    assert receipt.status == 1, (
        'Stake transaction failed. Receipt: {}'.format(receipt)
    )

    tx_hash = scatter.functions.pinned(bid_id).transact(std_tx({
            'from': pinner1,
            'gas': int(1e6),
        }))
    receipt = web3.eth.waitForTransactionReceipt(tx_hash)
    assert receipt.status == 1, (
        'Stake transaction failed. Receipt: {}'.format(receipt)
    )

    tx_hash = scatter.functions.stake(bid_id).transact(std_tx({
            'from': pinner2,
            'gas': int(5e6),
            'value': stake_value,
        }))
    receipt = web3.eth.waitForTransactionReceipt(tx_hash)
    assert receipt.status == 1, (
        'Stake transaction failed. Receipt: {}'.format(receipt)
    )

    tx_hash = scatter.functions.pinned(bid_id).transact(std_tx({
            'from': pinner2,
            'gas': int(6e6),
        }))
    receipt = web3.eth.waitForTransactionReceipt(tx_hash)
    assert receipt.status == 1, (
        'Stake transaction failed. Receipt: {}'.format(receipt)
    )

    assert has_event(challenge, 'Challenge', receipt), (
        'Challenge event not found'
    )
    c_evnt = get_event(challenge, 'Challenge', receipt)

    assert pinStake.functions.getStakeValue(bid_id, pinner1).call() > 0
    assert pinStake.functions.getStakeValue(bid_id, pinner2).call() > 0
    assert pinStake.functions.getStakeCount(bid_id).call() == 2

    ##
    # Pinner 1 needs to defend his honor
    ##
    half_hash_a = remove_0x_prefix(FILE_HASH_1)[32:]
    half_hash_b = remove_0x_prefix(FILE_HASH_2)[32:]
    sig = web3.eth.sign(pinner1, data=HexBytes(FILE_HASH_1))
    sig = remove_0x_prefix(sig.hex())
    r = sig[:64]
    s = sig[64:128]
    v = int(sig[128:130], 16) + 27

    assert len(r) == 64  # bytes32
    assert len(s) == 64
    assert len(half_hash_a) == 32  # bytes16
    assert len(half_hash_b) == 32

    txhash = challenge.functions.defend(
        c_evnt.args.challengeID,
        half_hash_a,
        half_hash_b,
        v,
        r,
        s
    ).transact(std_tx({
        'from': pinner1,
        'gas': int(6e6),
    }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1, (
        'Stake transaction failed. Receipt: {}'.format(receipt)
    )

    ##
    # Pinner 2 defense (This defense is invalid, order is irrelevant)
    ##
    half_hash_a = remove_0x_prefix(FILE_HASH_1)[:32]
    half_hash_b = remove_0x_prefix(RANDOM_HASH)[:32]
    sig = web3.eth.sign(pinner1, data=HexBytes(RANDOM_HASH))
    sig = remove_0x_prefix(sig.hex())
    r = sig[:64]
    s = sig[64:128]
    v = int(sig[128:130], 16) + 27

    txhash = challenge.functions.defend(
        c_evnt.args.challengeID,
        half_hash_a,
        half_hash_b,
        v,
        r,
        s
    ).transact(std_tx({
        'from': pinner2,
        'gas': int(6e6),
    }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1, (
        'Stake transaction failed. Receipt: {}'.format(receipt)
    )
    # Verify the defenses have failed
    assert has_event(challenge, 'DefenseFail', receipt), (
        'DefenseFail event not found'
    )

    # Verify the stakes have been burned
    assert pinStake.functions.getStakeValue(bid_id, pinner1).call() == 0
    assert pinStake.functions.getStakeValue(bid_id, pinner2).call() == 0
    assert pinStake.functions.getStakeCount(bid_id).call() == 0
