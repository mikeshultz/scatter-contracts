""" Tests for the Router contract """
from .utils import (
    get_accounts,
    std_tx,
)
from .consts import (
    ROUTER_CONTRACT_NAME,
    ZERO_ADDRESS,
    ADDRESS_1,
)


def test_router(web3, contracts):
    """ Test the Router contract """

    admin, _, _, _, _, _, _ = get_accounts(web3)

    test_name = web3.sha3(text='thisnamecannotbeactuallyusedbecausereasons')

    router = contracts.get(ROUTER_CONTRACT_NAME)
    assert router is not None, "router contract missing in {}".format(contracts)

    assert router.functions.owner().call() == admin, "Owner does not seem to be set properly."

    assert router.functions.get(test_name).call() == ZERO_ADDRESS
    txhash = router.functions.set(test_name, ADDRESS_1).transact(std_tx({
            'from': admin
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1
    assert router.functions.get(test_name).call() == ADDRESS_1
