from .utils import (
    get_remote_accounts,
    normalize_filehash,
)
from .consts import (
    REGISTER_CONTRACT_NAME,
    USER_STORE_CONTRACT_NAME,
    STD_GAS,
    STD_GAS_PRICE,
    ZERO_BYTES32,
    ZERO_ADDRESS,
    FILE_HASH_1,
)


def test_simple_registration(web3, contracts):
    """ Test a simple bid with minimum validations set """
    bidder, joe, mike, _, _, _ = get_remote_accounts(web3)

    register = contracts.get(REGISTER_CONTRACT_NAME)
    userStore = contracts.get(USER_STORE_CONTRACT_NAME)

    assert register.functions.router().call() != ZERO_ADDRESS, "Router not set"
    assert register.functions.env().call() != ZERO_ADDRESS, "Env not set"
    assert register.functions.userStore().call() != ZERO_ADDRESS, 'UserStore address not set'
    assert userStore.functions.writer().call() != ZERO_ADDRESS, 'UserStore writer address not set'
    assert userStore.functions.writer().call() == register.address, (
        'UserStore writer should be register'
    )
    assert normalize_filehash(register.functions.getUserFile(bidder).call()) == ZERO_BYTES32, (
        'User already registered'
    )

    txhash = register.functions.register(FILE_HASH_1).transact({
        'from': bidder,
        'gas': STD_GAS,
        'gasPrice': STD_GAS_PRICE,
    })
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1

    assert normalize_filehash(register.functions.getUserFile(bidder).call()) == FILE_HASH_1, (
        'User not registered'
    )
