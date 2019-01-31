""" Tests for PinStake """
from .utils import (
    get_accounts,
    std_tx,
)
from .consts import (
    MAIN_CONTRACT_NAME,
    PIN_STAKE_CONTRACT_NAME,
)


def test_add_stake(web3, contracts):
    """ Test addstake """
    owner, staker, _, _, _, _, Scatter = get_accounts(web3)

    bidID = 12345
    stakeValue = int(1e18)

    scatter = contracts.get(MAIN_CONTRACT_NAME)
    stake = contracts.get(PIN_STAKE_CONTRACT_NAME)
    assert scatter is not None, "Contract not found"
    assert stake is not None, "Contract not found"

    txhash = stake.functions.grant(Scatter).transact(std_tx({
            'from': owner
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1, (
        'grant transaction failed. Receipt: {}'.format(receipt)
    )
    assert stake.functions.isWriter(Scatter).call()

    assert stake.functions.getStakeValue(bidID, staker).call() == 0

    orig_count = stake.functions.getStakeCount(bidID).call()

    txhash = stake.functions.addStake(bidID, stakeValue, staker).transact(std_tx({
            'from': Scatter,
            'gas': int(1e6)
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1, (
        'addStake transaction failed. Receipt: {}'.format(receipt)
    )

    # Verify
    assert stake.functions.getStakeValue(bidID, staker).call() == stakeValue
    assert stake.functions.getStakeNonce(bidID, staker).call() == 1
    assert stake.functions.getStakeCount(bidID).call() == orig_count + 1
