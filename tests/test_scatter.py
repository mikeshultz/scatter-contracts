""" Tests for Scatter

Overview
--------
The general process for bidding:

1) User submits a bid for a file to be hosted
"""
import pytest
from hexbytes import HexBytes
from .utils import (
    get_remote_accounts,
    std_tx,
    has_event,
    get_event,
    normalize_filehash,
    time_travel,
)
from .consts import (
    MAIN_CONTRACT_NAME,
    STORE_CONTRACT_NAME,
    PIN_STAKE_CONTRACT_NAME,
    EMPTY_FILE_HASH,
    FILE_HASH_1,
    FILE_SIZE_1,
    DURATION_1,
    FILE_HASH_2,
    FILE_SIZE_2,
    DURATION_2,
    ENV_CONTRACT_NAME,
    ENV_MIN_BID,
    ENV_MIN_DURATION,
)

used_bid_IDs = []


def calculate_sway(min_valid, validations):
    assert min_valid <= len(validations)
    sway = 0
    for v in validations:
        if v is True:
            sway += 1
        else:
            sway -= 1
    return sway


def test_standard_bid(web3, contracts):
    """ Test a simple bid with minimum validations set """
    bidder, _, _, _, _, _ = get_remote_accounts(web3)

    scatter = contracts.get(MAIN_CONTRACT_NAME)
    bidStore = contracts.get(STORE_CONTRACT_NAME)
    assert scatter is not None, "Unable to find Scatter contract"
    assert bidStore is not None, "Unable to find BidStore contract"

    assert bidStore.functions.isWriter(scatter.address).call(), "Scatter not writer"
    assert scatter.functions.bidStore().call() == bidStore.address, "Invalid bidStore address"

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
    if has_event(scatter, 'BidInvalid', receipt):
        evdata = get_event(scatter, 'BidInvalid', receipt)
        assert False, evdata.args.reason
    assert has_event(scatter, 'BidSuccessful', receipt), (
        'BidSuccessful event not found'
    )

    evnt = get_event(scatter, 'BidSuccessful', receipt)
    assert evnt.args.bidID > -1, "Invalid bidID: {}".format(evnt.args.bidID)
    assert evnt.args.bidder == bidder, "Invalid bidder: {}".format(evnt.args.bidder)
    assert evnt.args.bidValue == bidValue, "Invalid bidValue: {}".format(evnt.args.bidValue)
    assert normalize_filehash(evnt.args.fileHash) == FILE_HASH_1, (
        "Invalid fileHash: {}".format(evnt.args.fileHash.hex())
    )
    assert evnt.args.fileSize == FILE_SIZE_1, "Invalid fileSize: {}".format(evnt.args.fileSize)


def test_bid_with_required_pinners(web3, contracts):
    """ Test a simple bid with requiredPinners set """
    global used_bid_IDs
    bidder, _, _, _, _, _ = get_remote_accounts(web3)

    scatter = contracts.get(MAIN_CONTRACT_NAME)

    assert scatter is not None, "Unable to find scatter contract"

    bidValue = web3.toWei(0.1, 'ether')

    tx_hash = scatter.functions.bid(
        FILE_HASH_1,
        FILE_SIZE_1,
        DURATION_1,
        bidValue,
        2
    ).transact(std_tx({
            'from': bidder,
            'gas': int(6e6),
            'value': bidValue
        }))

    receipt = web3.eth.waitForTransactionReceipt(tx_hash)
    assert receipt.status == 1, "Bid transaction failed. Receipt: {}".format(receipt)
    assert has_event(scatter, 'BidSuccessful', receipt), 'BidSuccessful event not found'

    evnt = get_event(scatter, 'BidSuccessful', receipt)
    (
        bidder,
        fileHash,
        fileSize,
        bidAmount,
        duration,
        requiredPinners,
    ) = scatter.functions.getBid(evnt.args.bidID).call()
    assert requiredPinners == 2, "Invalid validationPool: {}".format(evnt.args.validationPool)


def test_stake(web3, contracts):
    """ Test accepting bids """
    global used_bid_IDs
    bidder, pinner1, pinner2, _, _, _ = get_remote_accounts(web3)
    scatter = contracts.get(MAIN_CONTRACT_NAME)
    bidStore = contracts.get(STORE_CONTRACT_NAME)
    pinStake = contracts.get(PIN_STAKE_CONTRACT_NAME)
    env = contracts.get(ENV_CONTRACT_NAME)

    assert scatter.functions.pinStake().call() == pinStake.address
    assert scatter.functions.bidStore().call() == bidStore.address
    assert scatter.functions.env().call() == env.address

    bid_value = int(1e16)

    # Bid
    bid_hash = scatter.functions.bid(
        FILE_HASH_2,
        FILE_SIZE_2,
        DURATION_2,
        int(1e16),
    ).transact(std_tx({
        'from': bidder,
        'gas': int(6e6),
        'value': bid_value
    }))

    bid_receipt = web3.eth.waitForTransactionReceipt(bid_hash)
    assert bid_receipt.status == 1, "Bid transaction failed. Receipt: {}".format(bid_receipt)
    assert has_event(scatter, 'BidSuccessful', bid_receipt), 'BidSuccessful event not found'

    evnt = get_event(scatter, 'BidSuccessful', bid_receipt)
    bid_id = evnt.args.bidID
    assert bid_id not in used_bid_IDs
    used_bid_IDs.append(bid_id)
    assert bid_id > -1

    assert pinStake.functions.getStakeValue(bid_id, pinner1).call() == 0
    assert pinStake.functions.getStakeValue(bid_id, pinner2).call() == 0

    # Stake
    stake_hash = scatter.functions.stake(bid_id).transact(std_tx({
        'from': pinner1,
        'gas': int(1e6),
        'value': bid_value // 2
    }))
    stake_receipt = web3.eth.waitForTransactionReceipt(stake_hash)
    assert stake_receipt.status == 1, "Stake failed"
    assert has_event(scatter, 'PinStake', stake_receipt), "PinStake event not found"
    assert pinStake.functions.getStakeValue(bid_id, pinner1).call() == bid_value // 2

    # Second stake
    stake2_hash = scatter.functions.stake(bid_id).transact(std_tx({
        'from': pinner2,
        'gas': int(1e6),
        'value': bid_value // 2
    }))
    stake2_receipt = web3.eth.waitForTransactionReceipt(stake2_hash)
    assert stake2_receipt.status == 1, "Stake failed"
    assert has_event(scatter, 'PinStake', stake2_receipt), "PinStake event not found"
    assert pinStake.functions.getStakeValue(bid_id, pinner2).call() == bid_value // 2


def test_pinned(web3, contracts):
    """ Test a simple bid with minimum validations set """
    global used_bid_IDs
    bidder, pinner1, pinner2, _, jake, _ = get_remote_accounts(web3)
    scatter = contracts.get(MAIN_CONTRACT_NAME)
    pinStake = contracts.get(PIN_STAKE_CONTRACT_NAME)

    assert scatter.functions.pinStake().call() == pinStake.address

    bid_value = int(1e16)

    # Bid
    bid_hash = scatter.functions.bid(
        FILE_HASH_2,
        FILE_SIZE_2,
        DURATION_2,
        bid_value
    ).transact(std_tx({
        'from': bidder,
        'gas': int(6e6),
        'value': int(1e16) + int(1e14)
    }))

    bid_receipt = web3.eth.waitForTransactionReceipt(bid_hash)
    assert bid_receipt.status == 1, "Bid transaction failed. Receipt: {}".format(bid_receipt)
    assert has_event(scatter, 'BidSuccessful', bid_receipt), 'BidSuccessful event not found'

    evnt = get_event(scatter, 'BidSuccessful', bid_receipt)
    bid_id = evnt.args.bidID
    assert bid_id not in used_bid_IDs
    used_bid_IDs.append(bid_id)
    assert bid_id > -1

    stake1val = pinStake.functions.getStakeValue(bid_id, pinner1).call()
    stake2val = pinStake.functions.getStakeValue(bid_id, pinner2).call()
    assert stake1val == 0, "Expected 0 value for stake, got {}".format(stake1val)
    assert stake2val == 0, "Expected 0 value for stake, got {}".format(stake2val)

    # Stake
    stake_hash = scatter.functions.stake(bid_id).transact(std_tx({
        'from': pinner1,
        'gas': int(6e6),
        'value': bid_value // 2
    }))
    stake_receipt = web3.eth.waitForTransactionReceipt(stake_hash)
    assert stake_receipt.status == 1, "stake failed"
    assert has_event(scatter, 'PinStake', stake_receipt), "PinStake event not found"

    # Another stake
    stake2_hash = scatter.functions.stake(bid_id).transact(std_tx({
        'from': pinner2,
        'gas': int(1e6),
        'value': bid_value // 2
    }))
    stake2_receipt = web3.eth.waitForTransactionReceipt(stake2_hash)
    assert stake2_receipt.status == 1, "stake tx failed"
    assert has_event(scatter, 'PinStake', stake2_receipt), "PinStake event not found"

    # Rando can not pin without staking
    fail_pin_hash = scatter.functions.pinned(bid_id).transact(std_tx({
        'from': jake,
        'gas': int(1e6)
    }))
    fail_pin_receipt = web3.eth.waitForTransactionReceipt(fail_pin_hash)
    assert fail_pin_receipt.status == 1, "Pin tx failed"
    assert has_event(scatter, 'NotOpenToPin', fail_pin_receipt), (
        "NotOpenToPin event not found"
    )

    # Pin
    assert scatter.functions.isBidOpenForPin(bid_id, pinner1).call()
    pin_hash = scatter.functions.pinned(bid_id).transact(std_tx({
        'from': pinner1,
        'gas': int(6e6)
    }))
    pin_receipt = web3.eth.waitForTransactionReceipt(pin_hash)
    assert pin_receipt.status == 1, "pin failed"
    assert has_event(scatter, 'FilePinned', pin_receipt), "FilePinned event not found"

    # Second pinner pins
    assert scatter.functions.isBidOpenForPin(bid_id, pinner2).call()
    pin2_hash = scatter.functions.pinned(bid_id).transact(std_tx({
        'from': pinner2,
        'gas': int(6e6)
    }))
    pin2_receipt = web3.eth.waitForTransactionReceipt(pin2_hash)
    assert pin2_receipt.status == 1, "pin failed"
    assert has_event(scatter, 'FilePinned', pin2_receipt), "FilePinned event not found"


@pytest.mark.skip("TODO")
def test_withdraw(web3, contracts):
    """ Test withdraw functionality """

    bidder, hoster, validator1, validator2, validator3, kristen = get_remote_accounts(web3)
    scatter = contracts.get(MAIN_CONTRACT_NAME)

    bid_value = int(1e18)  # 1 Ether
    validation_value = int(1e17)  # 0.1 Ether
    gas_price = int(3e9)  # 3 gwei
    med_gas = int(3e6)

    # Bid and validate
    bid_hash = scatter.functions.bid(
        FILE_HASH_1,
        FILE_SIZE_1,
        DURATION_1,
        bid_value
    ).transact(std_tx({
        'from': bidder,
        'gas': int(6e6),
        'value': bid_value + validation_value,
    }))
    bid_receipt = web3.eth.waitForTransactionReceipt(bid_hash)
    assert bid_receipt.status == 1, "Bid transaction failed. Receipt: {}".format(bid_receipt)
    assert has_event(scatter, 'BidSuccessful', bid_receipt), 'BidSuccessful event not found'
    bid_evnt = get_event(scatter, 'BidSuccessful', bid_receipt)
    bid_id = bid_evnt.args.bidID
    pin_hash = scatter.functions.pinned(bid_id).transact(std_tx({
        'from': hoster,
        'gas': int(6e6)
    }))
    web3.eth.waitForTransactionReceipt(pin_hash)
    v1_hash = scatter.functions.validate(bid_id).transact(std_tx({
        'from': validator1,
        'gas': int(3e6)
    }))
    v2_hash = scatter.functions.validate(bid_id).transact(std_tx({
        'from': validator2,
        'gas': int(3e6)
    }))

    # GONNA GO BA- FORWARD IN TIME!
    time_travel(web3, DURATION_1)

    v3_hash = scatter.functions.validate(bid_id).transact(std_tx({
        'from': validator3,
        'gas': int(3e6)
    }))
    web3.eth.waitForTransactionReceipt(v1_hash)
    web3.eth.waitForTransactionReceipt(v2_hash)
    web3.eth.waitForTransactionReceipt(v3_hash)
    assert scatter.functions.satisfied(bid_id).call(), "Bid should be satisfied"

    # Bidder has nothing to withdraw
    bidder_txhash = scatter.functions.withdraw().transact(std_tx({'from': bidder}))
    bidder_receipt = web3.eth.waitForTransactionReceipt(bidder_txhash)
    assert has_event(scatter, 'WithdrawFailed', bidder_receipt), 'BidSuccessful event not found'
    bidder_withdraw_evnt = get_event(scatter, 'WithdrawFailed', bidder_receipt)
    assert bidder_withdraw_evnt.args.sender == bidder
    assert bidder_withdraw_evnt.args.reason == 'zero balance'

    # Hoster can withdraw
    hoster_balance_before = web3.eth.getBalance(hoster)
    assert scatter.functions.balance(hoster).call() > 0, "Nothing on the balanceSheet"
    assert scatter.functions.balance(hoster).call() == bid_value, "Wrong amount on the balanceSheet"

    hoster_txhash = scatter.functions.withdraw().transact(std_tx({
        'from': hoster,
        'gas': med_gas,
        'gasPrice': gas_price,
    }))
    hoster_receipt = web3.eth.waitForTransactionReceipt(hoster_txhash)
    assert hoster_receipt.status == 1, "Hoster withdraw failed. Receipt: {}".format(hoster_receipt)
    hoster_balance_after = web3.eth.getBalance(hoster)
    print(hoster_receipt)
    try:
        assert has_event(scatter, 'WithdrawFunds', hoster_receipt), (
            'WithdrawFunds event not found.'
        )
    except AssertionError as err:
        evt = get_event(scatter, 'WithdrawFailed', hoster_receipt)
        if evt:
            print("Found WithdrawFailed: {}".format(evt))
            ourguy = scatter.functions.getHoster(bid_id).call()
            assert ourguy == hoster, "Invalid sender, somehow"
            assert False, evt.args.reason
        else:
            raise err
    hoster_withdraw_evnt = get_event(scatter, 'WithdrawFunds', hoster_receipt)
    assert hoster_withdraw_evnt.args.value == bid_value, "Invalid value in event"
    assert hoster_withdraw_evnt.args.hoster == hoster
    assert hoster_balance_before < hoster_balance_after, "no value transferred"

    """ Predict the value change using the maximum amount of gas that could burn, and make sure to
    take that into account when checking that the proper value has been transferred.  The difference
    between seen and predicting should not be more than the max network fees. Predicting it exactly
    is a little difficult and could vary between compilers and seemingly trivial changes to the
    function.
    """
    seen_difference = hoster_balance_after - hoster_balance_before
    predicted_difference = hoster_withdraw_evnt.args.value - (gas_price * med_gas)
    assert seen_difference - predicted_difference < (gas_price * med_gas), "Invalid change"


@pytest.mark.skip("TODO")
def test_invalid_bids(web3, contracts):
    """ Test that the contract responds properly to invalid bids """

    bidder, _, _, _, _, banned = get_remote_accounts(web3)

    scatter = contracts.get(MAIN_CONTRACT_NAME)
    env = contracts.get(ENV_CONTRACT_NAME)

    bid_value = int(1e18)  # 1 Ether
    validation_value = int(1e17)  # 0.1 Ether
    gas = int(3e6)

    orig_bid_count = scatter.functions.getBidCount().call()

    # Test not enough value transferred
    bid1_hash = scatter.functions.bid(
        FILE_HASH_1,
        FILE_SIZE_1,
        DURATION_1,
        bid_value
    ).transact(std_tx({
        'from': bidder,
        'gas': gas,
        'value': bid_value,
    }))
    bid1_receipt = web3.eth.waitForTransactionReceipt(bid1_hash)
    assert bid1_receipt.status == 1, "Bid transaction failed. Receipt: {}".format(bid1_receipt)
    assert has_event(scatter, 'BidInvalid', bid1_receipt), 'BidInvalid event not found'

    # Assert there have been no new bids added
    assert orig_bid_count == scatter.functions.getBidCount().call()

    # Test fileHash of 0
    bid2_hash = scatter.functions.bid(
        HexBytes('0x0'),
        FILE_SIZE_1,
        DURATION_1,
        bid_value
    ).transact(std_tx({
        'from': bidder,
        'gas': gas,
        'value': bid_value + validation_value,
    }))
    bid2_receipt = web3.eth.waitForTransactionReceipt(bid2_hash)
    assert bid2_receipt.status == 1, "Bid transaction failed. Receipt: {}".format(bid2_receipt)
    assert has_event(scatter, 'BidInvalid', bid2_receipt), 'BidInvalid event not found'

    # Assert there have been no new bids added
    assert orig_bid_count == scatter.functions.getBidCount().call()

    # Test 'Empty' IPFS file hash
    bid3_hash = scatter.functions.bid(
        EMPTY_FILE_HASH,
        FILE_SIZE_1,
        DURATION_1,
        bid_value
    ).transact(std_tx({
        'from': bidder,
        'gas': gas,
        'value': bid_value + validation_value,
    }))
    bid3_receipt = web3.eth.waitForTransactionReceipt(bid3_hash)
    assert bid3_receipt.status == 1, "Bid transaction failed. Receipt: {}".format(bid3_receipt)
    assert has_event(scatter, 'BidInvalid', bid3_receipt), 'BidInvalid event not found'

    # Assert there have been no new bids added
    assert orig_bid_count == scatter.functions.getBidCount().call()

    # Test bidValue of 0
    bid4_hash = scatter.functions.bid(
        FILE_HASH_1,
        FILE_SIZE_1,
        DURATION_1,
        0
    ).transact(std_tx({
        'from': bidder,
        'gas': gas,
        'value': bid_value + validation_value,
    }))
    bid4_receipt = web3.eth.waitForTransactionReceipt(bid4_hash)
    assert bid4_receipt.status == 1, "Bid transaction failed. Receipt: {}".format(bid4_receipt)
    assert has_event(scatter, 'BidInvalid', bid4_receipt), 'BidInvalid event not found'

    # Assert there have been no new bids added
    assert orig_bid_count == scatter.functions.getBidCount().call()

    # Test a validation pool that's indivisible by minValidations
    bid5_hash = scatter.functions.bid(
        FILE_HASH_1,
        FILE_SIZE_1,
        DURATION_1,
        bid_value,
        2
    ).transact(std_tx({
        'from': bidder,
        'gas': gas,
        'value': bid_value + validation_value,
    }))
    bid5_receipt = web3.eth.waitForTransactionReceipt(bid5_hash)
    assert bid5_receipt.status == 1, "Bid transaction failed. Receipt: {}".format(bid5_receipt)
    assert has_event(scatter, 'BidInvalid', bid5_receipt), 'BidInvalid event not found'

    # Assert there have been no new bids added
    assert orig_bid_count == scatter.functions.getBidCount().call()

    # Test bidValue less than the minimum set in Env
    minValue = env.functions.getuint(ENV_MIN_BID).call()
    if minValue > 0:
        bid6_hash = scatter.functions.bid(
            FILE_HASH_1,
            FILE_SIZE_1,
            DURATION_1,
            minValue - 1
        ).transact(std_tx({
            'from': bidder,
            'gas': gas,
            'value': bid_value + validation_value,
        }))
        bid6_receipt = web3.eth.waitForTransactionReceipt(bid6_hash)
        assert bid6_receipt.status == 1, "Bid transaction failed. Receipt: {}".format(bid6_receipt)
        assert has_event(scatter, 'BidInvalid', bid6_receipt), 'BidInvalid event not found'

        # Assert there have been no new bids added
        assert orig_bid_count == scatter.functions.getBidCount().call()

    # Test duration less than the minimum duration stored in Env
    minDuration = env.functions.getuint(ENV_MIN_DURATION).call()
    bid7_hash = scatter.functions.bid(
        FILE_HASH_1,
        FILE_SIZE_1,
        minDuration - 1,
        bid_value
    ).transact(std_tx({
        'from': bidder,
        'gas': gas,
        'value': bid_value + validation_value,
    }))
    bid7_receipt = web3.eth.waitForTransactionReceipt(bid7_hash)
    assert bid7_receipt.status == 1, "Bid transaction failed. Receipt: {}".format(bid7_receipt)
    assert has_event(scatter, 'BidInvalid', bid7_receipt), 'BidInvalid event not found'

    # Assert there have been no new bids added
    assert orig_bid_count == scatter.functions.getBidCount().call()
