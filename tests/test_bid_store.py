""" Tests for BidStore

Overview
--------
The general process for bid storage: 

1) ...
"""
from datetime import datetime
from .utils import (
    get_accounts,
    std_tx,
    has_event,
    get_event,
    event_topics,
    normalize_filehash,
)
from .consts import (
    ZERO_ADDRESS,
    MAIN_CONTRACT_NAME,
    STORE_CONTRACT_NAME,
    ENV_CONTRACT_NAME,
    FILE_HASH_1,
    FILE_SIZE_1,
    DURATION_1,
    FILE_HASH_2,
    FILE_SIZE_2,
    DURATION_2,
    ENV_ACCEPT_WAIT,
    ENV_DEFAULT_MIN_VALIDATIONS,
)


def test_store_admin_funcs(web3, contracts):
    """ Test a simple addBid """
    admin, nobody, _, _, _, _, Scatter = get_accounts(web3)

    bidStore = contracts.get(STORE_CONTRACT_NAME)

    # Set the Scatter address
    txhash = bidStore.functions.grant(nobody).transact(std_tx({
            'from': admin,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1

    assert bidStore.functions.isWriter(nobody).call()
    txhash = bidStore.functions.grant(Scatter).transact(std_tx({
            'from': admin,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1
    assert bidStore.functions.isWriter(Scatter).call()

    # Setting of bidCount
    orig_bidCount = bidStore.functions.getBidCount().call()
    txhash = bidStore.functions.setNextBidID(1235).transact(std_tx({
            'from': admin,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1
    assert bidStore.functions.getBidCount().call() == 1234
    txhash = bidStore.functions.setNextBidID(orig_bidCount + 1).transact(std_tx({
            'from': admin,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1
    assert bidStore.functions.getBidCount().call() == orig_bidCount


def test_add_bid(web3, contracts):
    """ Test a simple addBid """
    admin, bidder, sAddress, _, _, _, _ = get_accounts(web3)

    bidStore = contracts.get(STORE_CONTRACT_NAME)

    # Set the Scatter address
    txhash = bidStore.functions.grant(sAddress).transact(std_tx({
            'from': admin,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1

    orig_bidCount = bidStore.functions.getBidCount().call()

    bidValue = int(1e17)
    requiredPinners = 2
    duration = 60*60

    # Add a bid
    bid_hash = bidStore.functions.addBid(
        bidder,
        FILE_HASH_1,
        FILE_SIZE_1,
        bidValue,
        duration,
        requiredPinners,
    ).transact(std_tx({
        'from': sAddress,
        'gas': int(1e6)
    }))

    bid_receipt = web3.eth.waitForTransactionReceipt(bid_hash)
    assert bid_receipt.status == 1, "Bid TX failed"

    bidID = orig_bidCount + 1

    # Veirfy tha tour new bid exists
    assert bidStore.functions.bidExists(bidID).call()
    assert bidStore.functions.getBidCount().call() == orig_bidCount + 1

    # Verify all the getters
    assert not bidStore.functions.isFullyPinned(bidID).call()
    assert bidStore.functions.getPinnerCount(bidID).call() == 0
    assert bidStore.functions.getBidder(bidID).call() == bidder
    assert normalize_filehash(bidStore.functions.getFileHash(bidID).call()) == FILE_HASH_1
    assert bidStore.functions.getFileSize(bidID).call() == FILE_SIZE_1
    assert bidStore.functions.getBidAmount(bidID).call() == bidValue


def test_pinning(web3, contracts):
    """ test the pinning functionality """
    admin, bidder, sAddress, _, _, otherHoster, hoster = get_accounts(web3)

    bidStore = contracts.get(STORE_CONTRACT_NAME)

    BID_GAS = int(1e6)

    # Verify state is expected
    assert bidStore.functions.isWriter(sAddress).call()

    bidValue = int(1e17)
    requiredPinners = 2
    duration = 60*60

    # Add a bid
    bid_hash = bidStore.functions.addBid(
        bidder,
        FILE_HASH_1,
        FILE_SIZE_1,
        bidValue,
        duration,
        requiredPinners,
    ).transact(std_tx({
        'from': sAddress,
        'gas': BID_GAS
    }))
    bid_receipt = web3.eth.waitForTransactionReceipt(bid_hash)
    assert bid_receipt.status == 1, "Bid TX failed"

    orig_count = bidStore.functions.getBidCount().call()
    assert orig_count > 0
    bidId = orig_count - 1
    assert bidStore.functions.bidExists(bidId).call()

    # Verify it's untouched
    assert bidStore.functions.getPinnerCount(bidId).call() == 0

    # Add a pin
    accept_hash = bidStore.functions.addPinner(bidId, hoster).transact(std_tx({
            'from': sAddress
        }))
    accept_receipt = web3.eth.waitForTransactionReceipt(accept_hash)
    assert accept_receipt.status == 1, "Pinned TX failed"

    assert bidStore.functions.getPinnerCount(bidId).call() == 1
    assert not bidStore.functions.isFullyPinned(bidId).call()

    # Add another pin
    accept_hash = bidStore.functions.addPinner(bidId, otherHoster).transact(std_tx({
            'from': sAddress
        }))
    accept_receipt = web3.eth.waitForTransactionReceipt(accept_hash)
    assert accept_receipt.status == 1, "Pinned TX failed"

    assert bidStore.functions.getPinnerCount(bidId).call() == 2
    assert bidStore.functions.isFullyPinned(bidId).call()

    # Verify again
    # TODO: Should pinned still be a date?
    # assert bidStore.functions.getPinned(bidId).call() > int(datetime.now().timestamp()) - 60 * 5
