""" Tests for the Env contract """
from .utils import (
    get_accounts,
    std_tx,
    has_event,
    get_event,
)
from .consts import (
    ENV_CONTRACT_NAME,
    UINT_HASH_1,
    UINT_VAL_1,
    STR_HASH_1,
    STR_VAL_1,
)

def test_env_owner(web3, contracts):
    """ Make sure owner is set """

    admin, _, _, _, _, _, _ = get_accounts(web3)

    env = contracts.get(ENV_CONTRACT_NAME)
    assert env is not None, "env contract missing"

    owner = env.functions.owner().call()

    assert owner == admin, "Owner does not seem to be set properly."


def test_env_uint(web3, contracts):
    """ Test uint set/fetch """

    admin, _, _, _, _, _, _ = get_accounts(web3)

    env = contracts.get(ENV_CONTRACT_NAME)

    assert env is not None, "env contract missing"

    set_txhash = env.functions.setuint(UINT_HASH_1, UINT_VAL_1).transact(std_tx({
            'from': admin,
        }))

    assert set_txhash is not None, "txhash not returned for setuit() transaction"

    set_receipt = web3.eth.waitForTransactionReceipt(set_txhash)

    assert set_receipt.status == 1, "setuint() transaction reverted"

    uintval = env.functions.getuint(UINT_HASH_1).call()

    assert uintval == UINT_VAL_1, "value returned from contract does not match"

def test_env_ban(web3, contracts):
    """ Test ban setting """

    admin, bidder, _, _, _, _, _ = get_accounts(web3)

    env = contracts.get(ENV_CONTRACT_NAME)

    assert env is not None, "env contract missing"

    # Ban bidder
    set_txhash = env.functions.ban(bidder).transact(std_tx({
            'from': admin,
        }))

    assert set_txhash is not None, "txhash not returned for ban() transaction"

    set_receipt = web3.eth.waitForTransactionReceipt(set_txhash)

    assert set_receipt.status == 1, "ban() transaction reverted"

    is_banned = env.functions.isBanned(bidder).call()

    assert is_banned, "ban does not appear to have worked"

    # Unban bidder
    set_txhash2 = env.functions.unban(bidder).transact(std_tx({
            'from': admin,
        }))

    assert set_txhash2 is not None, "txhash not returned for ban() transaction"

    set_receipt2 = web3.eth.waitForTransactionReceipt(set_txhash2)

    assert set_receipt2.status == 1, "ban() transaction reverted"

    is_banned2 = env.functions.isBanned(bidder).call()

    assert is_banned2 == False, "ban does not appear to have worked"

def test_env_str(web3, contracts):
    """ Test string set/fetch """

    admin, _, _, _, _, _, _ = get_accounts(web3)

    env = contracts.get(ENV_CONTRACT_NAME)

    assert env is not None, "env contract missing"

    print("!@#$!@#$!@#$: {}".format(std_tx({
            'from': admin,
        })))
    set_txhash = env.functions.setstr(STR_HASH_1, STR_VAL_1).transact(std_tx({
            'from': admin,
        }))

    assert set_txhash is not None, "txhash not returned for setstr() transaction"

    set_receipt = web3.eth.waitForTransactionReceipt(set_txhash)

    assert set_receipt.status == 1, "setstr() transaction reverted"

    strval = env.functions.getstr(STR_HASH_1).call()

    assert strval == STR_VAL_1, "value returned from contract does not match"
