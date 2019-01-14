""" Tests for the Router contract """
from .utils import (
    get_accounts,
    std_tx,
    has_event,
    get_event,
)
from .consts import (
    ROUTER_CONTRACT_NAME,
    ZERO_ADDRESS,
    ADDRESS_1,
)

def test_router(web3, contracts):
    """ Test the Router contract """

    admin, _, _, _, _, _, _ = get_accounts(web3)

    router = contracts.get(ROUTER_CONTRACT_NAME)
    assert router is not None, "router contract missing in {}".format(contracts)

    assert router.functions.owner().call() == admin, "Owner does not seem to be set properly."

    SCATTER_HASH = web3.sha3(text='Scatter')

    assert router.functions.get(SCATTER_HASH).call() == ZERO_ADDRESS
    txhash = router.functions.set(SCATTER_HASH, ADDRESS_1).transact(std_tx({
            'from': admin
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1
    assert router.functions.get(SCATTER_HASH).call() == ADDRESS_1
