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
    txhash = bidStore.functions.setScatter(nobody).transact(std_tx({
            'from': admin,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1

    assert bidStore.functions.scatterAddress().call() == nobody
    txhash = bidStore.functions.setScatter(Scatter).transact(std_tx({
            'from': admin,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1
    assert bidStore.functions.scatterAddress().call() == Scatter

    # Setting of bidCount
    assert bidStore.functions.bidCount().call() == 0
    txhash = bidStore.functions.setBidCount(1234).transact(std_tx({
            'from': admin,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1
    assert bidStore.functions.bidCount().call() == 1234
    txhash = bidStore.functions.setBidCount(0).transact(std_tx({
            'from': admin,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1
    assert bidStore.functions.bidCount().call() == 0


def test_add_bid(web3, contracts):
    """ Test a simple addBid """
    admin, bidder, sAddress, _, _, _, _ = get_accounts(web3)

    bidStore = contracts.get(STORE_CONTRACT_NAME)
    scatter = contracts.get(MAIN_CONTRACT_NAME)

    # Set the Scatter address
    txhash = bidStore.functions.setScatter(sAddress).transact(std_tx({
            'from': admin,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1

    # Verify no bids exist
    assert not bidStore.functions.bidExists(0).call()

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

    # Veirfy tha tour new bid exists
    assert bidStore.functions.bidExists(0).call()
    assert bidStore.functions.bidCount().call() == 1

    # Verify all the getters
    assert not bidStore.functions.isFullyPinned(0).call()
    assert bidStore.functions.getPinnerCount(0).call() == 0
    assert bidStore.functions.getBidder(0).call() == bidder
    assert normalize_filehash(bidStore.functions.getFileHash(0).call()) == FILE_HASH_1
    assert bidStore.functions.getFileSize(0).call() == FILE_SIZE_1
    assert bidStore.functions.getBidAmount(0).call() == bidValue


def test_pinning(web3, contracts):
    """ test the pinning functionality """
    admin, bidder, sAddress, _, _, otherHoster, hoster = get_accounts(web3)

    bidStore = contracts.get(STORE_CONTRACT_NAME)
    scatter = contracts.get(MAIN_CONTRACT_NAME)

    BID_GAS = int(1e6)
    VALID_GAS = int(6e6)

    # Verify state is expected
    assert bidStore.functions.scatterAddress().call() == sAddress

    bidValue = int(1e17)
    validationPool = int(1e17)
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

    orig_count = bidStore.functions.bidCount().call()
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

    # Set Scatter back so other tests don't fail
    txhash = bidStore.functions.setScatter(scatter.address).transact(std_tx({
            'from': admin
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1
