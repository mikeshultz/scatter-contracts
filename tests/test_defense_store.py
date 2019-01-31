""" Tests for ChallengeStore """
import pytest
from datetime import datetime
from eth_utils import remove_0x_prefix, add_0x_prefix
from hexbytes import HexBytes
from .utils import (
    get_accounts,
    std_tx,
)
from .consts import (
    MAIN_CONTRACT_NAME,
    DEFENSE_STORE_CONTRACT_NAME,
    FILE_HASH_1,
    FILE_HASH_2,
)


def test_add_defense(web3, contracts):
    """ Test a simple addDefense """

    if web3.is_eth_tester:
        pytest.skip("eth_sign is not currently supported by eth_tester")

    owner, defender, _, _, _, _, Scatter = get_accounts(web3)

    defenseStore = contracts.get(DEFENSE_STORE_CONTRACT_NAME)
    scatter = contracts.get(MAIN_CONTRACT_NAME)

    bidID = 123
    challengeID = 321
    addDefenseGas = int(1e6)

    txhash = defenseStore.functions.grant(Scatter).transact(std_tx({
            'from': owner,
        }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1, "grant tx failed"

    assert defenseStore.functions.isWriter(Scatter).call()

    assert defenseStore.functions.getDefenseCount().call() == 0, "invalid getDefenseCount"
    assert not defenseStore.functions.defenseExists(0).call(), "defense shouldn't exist"

    uniqueHash = FILE_HASH_1

    # Use the same hashing function the contract uses
    solHashed = scatter.functions.hashBytes32(uniqueHash).call()

    # The defender signs the uniqueHash
    signature_bytes = web3.eth.sign(defender, data=HexBytes(uniqueHash))

    # Prepare the signature to send to the contract
    signature = remove_0x_prefix(signature_bytes.hex())
    assert len(signature) == 130, "Invalid or unexpected length from eth_sign"
    r = add_0x_prefix(signature[:64])
    s = add_0x_prefix(signature[64:128])
    v = int(signature[128:130], 16) + 27
    assert v in (27, 28), "Invalid v"

    # Verify that we can recover now before even sending it to the contract
    recovery_address = web3.eth.account.recoverHash(
        solHashed,
        signature=signature_bytes
    )
    assert recovery_address == defender, (
        "Test recovery failed. This will fail in the contract as well."
    )

    nonce = 1
    half_hash_a = remove_0x_prefix(FILE_HASH_2)[:32]
    half_hash_b = remove_0x_prefix(FILE_HASH_1)[:32]

    txhash = defenseStore.functions.addDefense(
        bidID,
        challengeID,
        nonce,
        defender,
        half_hash_a,
        half_hash_b,
        v,
        r,
        s
    ).transact(std_tx({
        'from': Scatter,
        'gas': addDefenseGas,
    }))
    receipt = web3.eth.waitForTransactionReceipt(txhash)
    assert receipt.status == 1, "addDefense tx failed"

    assert defenseStore.functions.getDefenseCount().call() == 1, "invalid getDefenseCount"
    assert defenseStore.functions.defenseExists(1).call(), "Defense shouldn't exist"

    storedDefense = defenseStore.functions.getDefense(1).call()

    assert storedDefense[0] == bidID
    assert storedDefense[1] == challengeID
    assert storedDefense[2] == 1
    assert storedDefense[3] == 1
    assert storedDefense[4] >= int(datetime.now().timestamp()) - 300
    assert storedDefense[5] == defender
    assert storedDefense[6].hex() == half_hash_a
    assert storedDefense[7].hex() == half_hash_b
    assert storedDefense[8] == v
    assert web3.toHex(storedDefense[9]) == r
    assert web3.toHex(storedDefense[10]) == s
