""" Tests for UserStore contract """
from .utils import (
    get_accounts,
    std_tx,
    normalize_filehash,
)
from .consts import (
    USER_STORE_CONTRACT_NAME,
    ZERO_BYTES32,
    FILE_HASH_1,
)


def test_storage(web3, contracts):
    """ Test storage operations with UserStore """
    owner, writer, _, _, _, _, _ = get_accounts(web3)

    userStore = contracts.get(USER_STORE_CONTRACT_NAME)

    orig_writer = userStore.functions.writer().call()

    txhash = userStore.functions.setWriter(writer).transact(std_tx({
        'from': owner
    }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1
    assert userStore.functions.writer().call() == writer, 'setWriter() failed'

    tval_uint = 123
    tval_string = 'oneTwo three'
    tval_bytes32 = FILE_HASH_1
    test_hash = web3.sha3(text='test1')

    assert userStore.functions.getUint(test_hash).call() == 0
    userStore.functions.setUint(test_hash, tval_uint).transact(std_tx({
        'from': owner
    }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1
    assert userStore.functions.getUint(test_hash).call() == tval_uint

    assert userStore.functions.getString(test_hash).call() == ''
    userStore.functions.setString(test_hash, tval_string).transact(std_tx({
        'from': owner
    }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1
    assert userStore.functions.getString(test_hash).call() == tval_string

    assert normalize_filehash(userStore.functions.getBytes32(test_hash).call()) == ZERO_BYTES32
    userStore.functions.setBytes32(test_hash, tval_bytes32).transact(std_tx({
        'from': owner
    }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1
    assert normalize_filehash(userStore.functions.getBytes32(test_hash).call()) == tval_bytes32

    # Set the writer back to the original one
    txhash = userStore.functions.setWriter(orig_writer).transact(std_tx({
        'from': owner
    }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1
    assert userStore.functions.writer().call() == orig_writer, 'setWriter() failed'
