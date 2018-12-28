import pytest

from .utils import (
    get_accounts,
    get_std_tx,
    has_event,
    get_event,
    event_topics,
    normalize_event_filehash,
)
from .consts import (
    BID_CONTRACT_NAME,
    FILE_HASH_1,
    FILE_SIZE_1,
    DURATION_1,
)

def test_standard_bid(web3, contracts):
    """ Test a simple bid with minimum validations set """
    _, bidder, _, _, _, _ = get_accounts(web3)

    bid = contracts.get(BID_CONTRACT_NAME)

    assert bid is not None, "Unable to find bid contract"

    bidValue = web3.toWei(0.1, 'ether')
    validationPool = web3.toWei(0.01, 'ether')

    tx_hash = bid.functions.bid(
        FILE_HASH_1,
        FILE_SIZE_1,
        DURATION_1,
        bidValue,
        validationPool
    ).transact(get_std_tx(bidder))

    receipt = web3.eth.waitForTransactionReceipt(tx_hash)

    if has_event(bid, 'BidInvalid', receipt):
        evdata = get_event(bid, 'BidInvalid', receipt)
        assert False, evdata.args.reason
    assert has_event(bid, 'BidSuccessful', receipt), 'BidSuccessful event not found'

    evnt = get_event(bid, 'BidSuccessful', receipt)
    assert evnt.args.bidId > 0, "Invalid bidId: {}".format(evnt.args.bidId)
    assert evnt.args.bidder == bidder, "Invalid bidder: {}".format(evnt.args.bidder)
    assert evnt.args.bidValue == bidValue, "Invalid bidValue: {}".format(evnt.args.bidValue)
    assert evnt.args.validationPool == validationPool, "Invalid validationPool: {}".format(evnt.args.validationPool)
    assert normalize_event_filehash(evnt.args.fileHash) == FILE_HASH_1, "Invalid fileHash: {}".format(evnt.args.fileHash.hex())
    assert evnt.args.fileSize == FILE_SIZE_1, "Invalid fileSize: {}".format(evnt.args.fileSize)

def test_bid_with_minvalidations(web3, contracts):
    """ Test a simple bid with minimum validations set """
    _, bidder, _, _, _, _ = get_accounts(web3)

    bid = contracts.get(BID_CONTRACT_NAME)

    assert bid is not None, "Unable to find bid contract"

    bidValue = web3.toWei(0.1, 'ether')
    validationPool = web3.toWei(0.01, 'ether')

    tx_hash = bid.functions.bid(
        FILE_HASH_1,
        FILE_SIZE_1,
        DURATION_1,
        bidValue,
        validationPool,
        5
    ).transact(get_std_tx(bidder))

    receipt = web3.eth.waitForTransactionReceipt(tx_hash)

    assert has_event(bid, 'BidSuccessful', receipt), 'BidSuccessful event not found'
    
    evnt = get_event(bid, 'BidSuccessful', receipt)
    (
        bidder,
        fileHash,
        fileSize,
        bidAmount,
        validationPool,
        duration,
        minValidations,
    ) = bid.functions.getBid(evnt.args.bidId).call()
    assert minValidations == 5, "Invalid validationPool: {}".format(evnt.args.validationPool)
