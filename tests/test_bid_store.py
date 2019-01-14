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
    BID_CONTRACT_NAME,
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
    
    bidStore = contracts.get('BidStore')

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
    
    bidStore = contracts.get('BidStore')

    # Set the Scatter address
    txhash = bidStore.functions.setScatter(sAddress).transact(std_tx({
            'from': admin,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1

    # Verify no bids exist
    assert not bidStore.functions.bidExists(0).call()

    bidValue = int(1e17)
    validationPool = int(1e17)
    minValidations = 2
    duration = 60*60
    
    # Add a bid
    bid_hash = bidStore.functions.addBid(
        bidder,
        FILE_HASH_1,
        FILE_SIZE_1,
        bidValue,
        validationPool,
        minValidations,
        duration
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
    assert not bidStore.functions.isPinned(0).call()
    assert bidStore.functions.getPinned(0).call() == 0
    assert bidStore.functions.getBidder(0).call() == bidder
    assert bidStore.functions.getAccepted(0).call() == 0
    assert bidStore.functions.getHoster(0).call() == ZERO_ADDRESS
    assert normalize_filehash(bidStore.functions.getFileHash(0).call()) == FILE_HASH_1
    assert bidStore.functions.getFileSize(0).call() == FILE_SIZE_1
    assert bidStore.functions.getValidationPool(0).call() == validationPool
    assert bidStore.functions.getBidAmount(0).call() == bidValue
    assert bidStore.functions.getValidationCount(0).call() == 0


def test_add_validation(web3, contracts):
    """ Test a simple addBid """
    admin, bidder, sAddress, validator1, validator2, validator3, _ = get_accounts(web3)
    
    bidStore = contracts.get('BidStore')

    BID_ID = 0
    AV_GAS = int(6e6)

    # Verify state is expected
    assert bidStore.functions.scatterAddress().call() == sAddress
    assert bidStore.functions.getValidationCount(0).call() == 0
    assert bidStore.functions.getBidder(0).call() == bidder

    # Add a positive validation
    txhash = bidStore.functions.addValidation(BID_ID, validator1, True).transact(std_tx({
            'from': sAddress,
            'gas': AV_GAS,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1
    assert bidStore.functions.getValidationCount(BID_ID).call() == 1
    validation1 = bidStore.functions.getValidation(BID_ID, 0).call()
    assert len(validation1) == 4, "Unexpected return values"
    assert validation1[0] > 0  # when
    assert validation1[1] == validator1  # validator
    assert validation1[2] is True  # isValid
    assert validation1[3] is False  # paid
    assert bidStore.functions.getValidationIsValid(BID_ID, 0).call()
    assert bidStore.functions.getValidator(BID_ID, 0).call() == validator1
    assert bidStore.functions.getValidatorIndex(BID_ID, validator1).call() == 0

    # Add a negative validation
    txhash = bidStore.functions.addValidation(BID_ID, validator2, False).transact(std_tx({
            'from': sAddress,
            'gas': AV_GAS,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1
    assert bidStore.functions.getValidationCount(BID_ID).call() == 2
    validation2 = bidStore.functions.getValidation(BID_ID, 1).call()
    assert len(validation2) == 4, "Unexpected return values"
    assert validation2[0] > 0  # when
    assert validation2[1] == validator2  # validator
    assert validation2[2] is False  # isValid
    assert validation2[3] is False  # paid
    assert not bidStore.functions.getValidationIsValid(BID_ID, 1).call()
    assert bidStore.functions.getValidator(BID_ID, 1).call() == validator2
    assert bidStore.functions.getValidatorIndex(BID_ID, validator2).call() == 1

    # Add another positive validation
    txhash = bidStore.functions.addValidation(BID_ID, validator3, True).transact(std_tx({
            'from': sAddress,
            'gas': AV_GAS,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1
    assert bidStore.functions.getValidationCount(BID_ID).call() == 3
    validation3 = bidStore.functions.getValidation(BID_ID, 2).call()
    assert len(validation3) == 4, "Unexpected return values"
    assert validation3[0] > 0  # when
    assert validation3[1] == validator3  # validator
    assert validation3[2] is True  # isValid
    assert validation3[3] is False  # paid
    assert bidStore.functions.getValidationIsValid(BID_ID, 2).call()
    assert bidStore.functions.getValidator(BID_ID, 2).call() == validator3
    assert bidStore.functions.getValidatorIndex(BID_ID, validator3).call() == 2

    assert bidStore.functions.setValidatorPaid(BID_ID, 0).transact(std_tx({
            'from': sAddress,
            'gas': AV_GAS,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1

    paid_validation = bidStore.functions.getValidation(BID_ID, 0).call()
    assert len(paid_validation) == 4, "Unexpected return values"
    assert paid_validation[3] is True  # paid

def test_pinning(web3, contracts):
    """ test the pinning functionality """
    admin, bidder, sAddress, _, _, otherHoster, hoster = get_accounts(web3)
    
    bidStore = contracts.get('BidStore')

    BID_GAS = int(1e6)
    VALID_GAS = int(6e6)

    # Verify state is expected
    assert bidStore.functions.scatterAddress().call() == sAddress

    bidValue = int(1e17)
    validationPool = int(1e17)
    minValidations = 2
    duration = 60*60
    
    # Add a bid
    bid_hash = bidStore.functions.addBid(
        bidder,
        FILE_HASH_1,
        FILE_SIZE_1,
        bidValue,
        validationPool,
        minValidations,
        duration
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
    assert bidStore.functions.getAccepted(bidId).call() == 0
    assert bidStore.functions.getPinned(bidId).call() == 0
    assert bidStore.functions.getHoster(bidId).call() == ZERO_ADDRESS

    # Now touch it
    accept_hash = bidStore.functions.setAcceptNow(bidId, hoster).transact(std_tx({
            'from': sAddress
        }))
    accept_receipt = web3.eth.waitForTransactionReceipt(accept_hash)
    assert accept_receipt.status == 1, "Accept TX failed"

    # Verify again
    assert bidStore.functions.getAccepted(bidId).call() > int(datetime.now().timestamp()) - 60 * 5
    assert bidStore.functions.getPinned(bidId).call() == 0
    assert bidStore.functions.getHoster(bidId).call() == hoster

    # Set pin
    accept_hash = bidStore.functions.setPinned(bidId, otherHoster).transact(std_tx({
            'from': sAddress
        }))
    accept_receipt = web3.eth.waitForTransactionReceipt(accept_hash)
    assert accept_receipt.status == 1, "Accept TX failed"

    # Verify again
    assert bidStore.functions.getAccepted(bidId).call() > int(datetime.now().timestamp()) - 60 * 5
    assert bidStore.functions.getPinned(bidId).call() > int(datetime.now().timestamp()) - 60 * 5
    assert bidStore.functions.getHoster(bidId).call() == otherHoster
