""" Tests for ChallengeStore """
from datetime import datetime
from .utils import (
    get_accounts,
    std_tx,
)
from .consts import (
    CHALLENGE_STORE_CONTRACT_NAME,
    ZERO_ADDRESS,
)


def test_add_challenge(web3, contracts):
    """ Test a simple addChallenge """
    owner, challenger, _, _, _, _, Scatter = get_accounts(web3)

    challengeStore = contracts.get(CHALLENGE_STORE_CONTRACT_NAME)

    bidID = 123
    addChallengeGas = int(1e6)

    txhash = challengeStore.functions.grant(Scatter).transact(std_tx({
            'from': owner,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1, "grant tx failed"

    assert challengeStore.functions.isWriter(Scatter).call()

    assert challengeStore.functions.getChallengeCount().call() == 0, "invalid getChallengeCount"
    assert not challengeStore.functions.challengeExists(0).call(), "challnge shouldn't exist"

    txhash = challengeStore.functions.addChallenge(bidID, challenger).transact(std_tx({
            'from': Scatter,
            'gas': addChallengeGas,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1, "addChallenge tx failed"

    assert challengeStore.functions.getChallengeCount().call() == 1, "invalid getChallengeCount"
    assert challengeStore.functions.challengeExists(1).call(), "challnge shouldn't exist"

    (cBidID, when, cAddress) = challengeStore.functions.getChallenge(1).call()

    assert cBidID == bidID
    assert when >= int(datetime.now().timestamp()) - 300
    assert cAddress == challenger
