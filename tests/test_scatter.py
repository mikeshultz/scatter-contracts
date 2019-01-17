""" Tests for Scatter

Overview
--------
The general process for bidding:

1) User submits a bid for a file to be hosted
"""
from hexbytes import HexBytes
from .utils import (
    get_accounts,
    std_tx,
    has_event,
    get_event,
    normalize_filehash,
    time_travel,
)
from .consts import (
    MAIN_CONTRACT_NAME,
    STORE_CONTRACT_NAME,
    EMPTY_FILE_HASH,
    FILE_HASH_1,
    FILE_SIZE_1,
    DURATION_1,
    FILE_HASH_2,
    FILE_SIZE_2,
    DURATION_2,
    ENV_CONTRACT_NAME,
    ENV_ACCEPT_WAIT,
    ENV_DEFAULT_MIN_VALIDATIONS,
    ENV_MIN_BID,
    ENV_MIN_DURATION,
)


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
    _, bidder, _, _, _, _, _ = get_accounts(web3)

    scatter = contracts.get(MAIN_CONTRACT_NAME)
    bidStore = contracts.get(STORE_CONTRACT_NAME)
    assert scatter is not None, "Unable to find Scatter contract"
    assert bidStore is not None, "Unable to find BidStore contract"

    assert bidStore.functions.scatterAddress().call() == scatter.address, (
        "BidStore.scatterAddress is wrong"
    )
    assert scatter.functions.bidStore().call() == bidStore.address, "Invalid bidStore address"

    bidValue = web3.toWei(0.1, 'ether')
    validationPool = web3.toWei(0.01, 'ether')

    tx_hash = scatter.functions.bid(
        FILE_HASH_1,
        FILE_SIZE_1,
        DURATION_1,
        bidValue,
        validationPool
    ).transact(std_tx({
            'from': bidder,
            'gas': int(6e6),
            'value': bidValue + validationPool
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
    assert evnt.args.bidId > -1, "Invalid bidId: {}".format(evnt.args.bidId)
    assert evnt.args.bidder == bidder, "Invalid bidder: {}".format(evnt.args.bidder)
    assert evnt.args.bidValue == bidValue, "Invalid bidValue: {}".format(evnt.args.bidValue)
    assert evnt.args.validationPool == validationPool, (
        "Invalid validationPool: {}".format(evnt.args.validationPool)
    )
    assert normalize_filehash(evnt.args.fileHash) == FILE_HASH_1, (
        "Invalid fileHash: {}".format(evnt.args.fileHash.hex())
    )
    assert evnt.args.fileSize == FILE_SIZE_1, "Invalid fileSize: {}".format(evnt.args.fileSize)


def test_bid_with_minvalidations(web3, contracts):
    """ Test a simple bid with minimum validations set """
    _, bidder, _, _, _, _, _ = get_accounts(web3)

    scatter = contracts.get(MAIN_CONTRACT_NAME)

    assert scatter is not None, "Unable to find scatter contract"

    bidValue = web3.toWei(0.1, 'ether')
    validationPool = web3.toWei(0.01, 'ether')

    tx_hash = scatter.functions.bid(
        FILE_HASH_1,
        FILE_SIZE_1,
        DURATION_1,
        bidValue,
        validationPool,
        5
    ).transact(std_tx({
            'from': bidder,
            'gas': int(6e6),
            'value': bidValue + validationPool
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
        validationPool,
        duration,
        minValidations,
    ) = scatter.functions.getBid(evnt.args.bidId).call()
    assert minValidations == 5, "Invalid validationPool: {}".format(evnt.args.validationPool)


def test_accept(web3, contracts):
    """ Test accepting bids """
    _, bidder, hoster, _, _, joe, _ = get_accounts(web3)
    scatter = contracts.get(MAIN_CONTRACT_NAME)
    env = contracts.get(ENV_CONTRACT_NAME)

    # Bid
    bid_hash = scatter.functions.bid(
        FILE_HASH_2,
        FILE_SIZE_2,
        DURATION_2,
        int(1e16),
        int(1e14)
    ).transact(std_tx({
        'from': bidder,
        'gas': int(6e6),
        'value': int(1e16) + int(1e14)
    }))

    bid_receipt = web3.eth.waitForTransactionReceipt(bid_hash)
    assert bid_receipt.status == 1, "Bid transaction failed. Receipt: {}".format(bid_receipt)
    assert has_event(scatter, 'BidSuccessful', bid_receipt), 'BidSuccessful event not found'

    evnt = get_event(scatter, 'BidSuccessful', bid_receipt)
    bid_id = evnt.args.bidId

    # Accept
    accept_hash = scatter.functions.accept(bid_id).transact(std_tx({
        'from': hoster
    }))
    accept_receipt = web3.eth.waitForTransactionReceipt(accept_hash)
    assert accept_receipt.status == 1, "accept failed"
    assert has_event(scatter, 'Accepted', accept_receipt), "Accepted event not found"

    # Joe can not also accept before wait period is over
    accept2_hash = scatter.functions.accept(bid_id).transact(std_tx({
        'from': joe
    }))
    accept2_receipt = web3.eth.waitForTransactionReceipt(accept2_hash)
    assert accept2_receipt.status == 1, "accept failed"
    assert has_event(scatter, 'AcceptWait', accept2_receipt), "AcceptWait event not found"

    # Time travel past set acceptHoldDuration
    wait = env.functions.getuint(ENV_ACCEPT_WAIT).call()
    web3.providers[0].make_request("evm_increaseTime", [wait])

    # Joe can accept after wait period is over
    accept3_hash = scatter.functions.accept(bid_id).transact(std_tx({
        'from': joe
    }))
    accept3_receipt = web3.eth.waitForTransactionReceipt(accept3_hash)
    assert accept3_receipt.status == 1, "accept failed"
    assert has_event(scatter, 'Accepted', accept_receipt), "Accepted event not found"


def test_pinned(web3, contracts):
    """ Test a simple bid with minimum validations set """
    _, bidder, hoster, _, _, jake, _ = get_accounts(web3)
    scatter = contracts.get(MAIN_CONTRACT_NAME)

    # Bid
    bid_hash = scatter.functions.bid(
        FILE_HASH_2,
        FILE_SIZE_2,
        DURATION_2,
        int(1e16),
        int(1e14)
    ).transact(std_tx({
        'from': bidder,
        'gas': int(6e6),
        'value': int(1e16) + int(1e14)
    }))

    bid_receipt = web3.eth.waitForTransactionReceipt(bid_hash)
    assert bid_receipt.status == 1, "Bid transaction failed. Receipt: {}".format(bid_receipt)
    assert has_event(scatter, 'BidSuccessful', bid_receipt), 'BidSuccessful event not found'

    evnt = get_event(scatter, 'BidSuccessful', bid_receipt)
    bid_id = evnt.args.bidId

    # Accept
    accept_hash = scatter.functions.accept(bid_id).transact(std_tx({'from': hoster}))
    accept_receipt = web3.eth.waitForTransactionReceipt(accept_hash)
    assert accept_receipt.status == 1, "accept failed"
    assert has_event(scatter, 'Accepted', accept_receipt), "Accepted event not found"

    # Rando can not pin after accepted by another
    accept2_hash = scatter.functions.accept(bid_id).transact(std_tx({'from': jake}))
    accept2_receipt = web3.eth.waitForTransactionReceipt(accept2_hash)
    assert accept2_receipt.status == 1, "accept failed"
    assert has_event(scatter, 'AcceptWait', accept2_receipt), "AcceptWait event not found"

    # Pin
    pin_hash = scatter.functions.pinned(bid_id).transact(std_tx({
        'from': hoster,
        'gas': int(6e6)
    }))
    pin_receipt = web3.eth.waitForTransactionReceipt(pin_hash)
    assert pin_receipt.status == 1, "pin failed"
    assert has_event(scatter, 'Pinned', pin_receipt), "Pinned event not found"


def test_validation(web3, contracts):
    """ Test the full validation process

    Notes:
    - Must win majority by minValidations
    - A bid doesn't need to be accepted to pin, but if accepted, it can only be pinned by the user
        who accepted the bid(if not expired).
    - Bidder can not validate their own bid
    """
    _, bidder, hoster, validator1, validator2, validator3, validator4 = get_accounts(web3)
    scatter = contracts.get(MAIN_CONTRACT_NAME)
    env = contracts.get(ENV_CONTRACT_NAME)

    # Bid
    bid_hash = scatter.functions.bid(
        FILE_HASH_1,
        FILE_SIZE_1,
        DURATION_1,
        int(1e18),  # 1 Ether
        int(1e17)  # 0.1 Ether
    ).transact(std_tx({
        'from': bidder,
        'gas': int(6e6),
        'value': int(1e18) + int(1e17)
    }))

    bid_receipt = web3.eth.waitForTransactionReceipt(bid_hash)
    assert bid_receipt.status == 1, "Bid transaction failed. Receipt: {}".format(bid_receipt)
    assert has_event(scatter, 'BidSuccessful', bid_receipt), 'BidSuccessful event not found'

    evnt = get_event(scatter, 'BidSuccessful', bid_receipt)
    bid_id = evnt.args.bidId

    # Pin
    pin_hash = scatter.functions.pinned(bid_id).transact(std_tx({
        'from': hoster,
        'gas': int(6e6)
    }))
    pin_receipt = web3.eth.waitForTransactionReceipt(pin_hash)
    assert pin_receipt.status == 1, "pin failed"
    assert has_event(scatter, 'Pinned', pin_receipt), "Pinned event not found"

    # Validation #1
    v1_hash = scatter.functions.validate(bid_id).transact(std_tx({
        'from': validator1,
        'gas': int(6e6)
    }))
    v1_receipt = web3.eth.waitForTransactionReceipt(v1_hash)
    assert v1_receipt.status == 1, "validation #1 tx failed"
    assert has_event(scatter, 'ValidationOcurred', v1_receipt), "Pinned event not found"

    # Check the Validaton data before moving on
    evnt = get_event(scatter, 'ValidationOcurred', v1_receipt)
    assert len(evnt.args) == 3, "Invalid argument count in ValidationOcurred"
    assert evnt.args.bidId == bid_id
    assert evnt.args.validator == validator1
    assert evnt.args.isValid

    # Validation #2 (invalid)
    v2_hash = scatter.functions.invalidate(bid_id).transact(std_tx({
        'from': validator2,
        'gas': int(6e6)
    }))
    v2_receipt = web3.eth.waitForTransactionReceipt(v2_hash)
    assert v2_receipt.status == 1, "validation #2 tx failed"
    assert has_event(scatter, 'ValidationOcurred', v2_receipt), "Pinned event not found"

    # Check the Validaton data before moving on
    evnt2 = get_event(scatter, 'ValidationOcurred', v2_receipt)
    assert len(evnt2.args) == 3, "Invalid argument count in ValidationOcurred"
    assert evnt2.args.bidId == bid_id
    assert evnt2.args.validator == validator2
    assert evnt2.args.isValid is False

    # Validation #3 (valid)
    v3_hash = scatter.functions.validate(bid_id).transact(std_tx({
        'from': validator3,
        'gas': int(6e6)
    }))
    v3_receipt = web3.eth.waitForTransactionReceipt(v3_hash)
    assert v2_receipt.status == 1, "validation #3 tx failed"
    assert has_event(scatter, 'ValidationOcurred', v3_receipt), "Pinned event not found"

    # Check the Validaton data before moving on
    evnt3 = get_event(scatter, 'ValidationOcurred', v3_receipt)
    assert len(evnt3.args) == 3, "Invalid argument count in ValidationOcurred"
    assert evnt3.args.bidId == bid_id
    assert evnt3.args.validator == validator3
    assert evnt3.args.isValid

    # Validation #4 (valid)
    v4_hash = scatter.functions.validate(bid_id).transact(std_tx({
        'from': validator4,
        'gas': int(6e6)
    }))
    v4_receipt = web3.eth.waitForTransactionReceipt(v4_hash)
    assert v4_receipt.status == 1, "validation #3 tx failed"
    assert has_event(scatter, 'ValidationOcurred', v4_receipt), "Pinned event not found"

    # Check the Validaton data before moving on
    evnt4 = get_event(scatter, 'ValidationOcurred', v4_receipt)
    assert len(evnt3.args) == 3, "Invalid argument count in ValidationOcurred"
    assert evnt4.args.bidId == bid_id
    assert evnt4.args.validator == validator4
    assert evnt4.args.isValid

    validationCount = scatter.functions.getValidationCount(bid_id).call()

    # Verify the bid
    (
        bidder,
        fileHash,
        fileSize,
        bidAmount,
        validationPool,
        duration,
        minValidations,
    ) = scatter.functions.getBid(bid_id).call()
    assert bidder == bidder
    defaultMinValidations = env.functions.getuint(ENV_DEFAULT_MIN_VALIDATIONS).call()
    assert minValidations == defaultMinValidations
    assert minValidations <= validationCount

    # Get all of the validations
    validations = []
    for i in range(0, validationCount):
        (
            v_when,
            v_validator,
            v_isValid,
            v_paid
        ) = scatter.functions.getValidation(bid_id, i).call()
        assert v_validator in [validator1, validator2, validator3, validator4]
        validations.append(v_isValid)

    # Calculate sway on test side
    projected_sway = calculate_sway(minValidations, validations)

    # Make sure sway is accurate
    sway = scatter.functions.validationSway(bid_id).call()
    assert sway == projected_sway
    assert sway != 0
    majority_sway = float(minValidations) / float(sway)
    assert -2.0 < majority_sway < 2.0, ("mojority sway should not more then 2 or less than -2 but "
                                        "got {} (minValid: {}; sway: {})".format(
                                            majority_sway,
                                            minValidations,
                                            sway))

    # Make sure the bid is satisfied
    satisfied = scatter.functions.satisfied(bid_id).call()
    assert satisfied, "bid should be satisfied but got: {}".format(satisfied)


def test_withdraw(web3, contracts):
    """ Test withdraw functionality """

    _, bidder, hoster, validator1, validator2, validator3, kristen = get_accounts(web3)
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
        bid_value,
        validation_value
    ).transact(std_tx({
        'from': bidder,
        'gas': int(6e6),
        'value': bid_value + validation_value,
    }))
    bid_receipt = web3.eth.waitForTransactionReceipt(bid_hash)
    assert bid_receipt.status == 1, "Bid transaction failed. Receipt: {}".format(bid_receipt)
    assert has_event(scatter, 'BidSuccessful', bid_receipt), 'BidSuccessful event not found'
    bid_evnt = get_event(scatter, 'BidSuccessful', bid_receipt)
    bid_id = bid_evnt.args.bidId
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
        assert has_event(scatter, 'Withdraw', hoster_receipt), (
            'Withdraw event not found.'
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
    hoster_withdraw_evnt = get_event(scatter, 'Withdraw', hoster_receipt)
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


def test_invalid_bids(web3, contracts):
    """ Test that the contract responds properly to invalid bids """

    _, bidder, _, _, _, _, banned = get_accounts(web3)

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
        bid_value,
        validation_value
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
        bid_value,
        validation_value
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
        bid_value,
        validation_value
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
        0,
        validation_value
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
        2,
        3
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
            minValue - 1,
            validation_value
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
        bid_value,
        validation_value
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
