from attrdict import AttrDict
from hexbytes import HexBytes
from web3 import Web3
from web3.utils.events import get_event_data
from .consts import DEPLOYER_ACCOUNT


def get_accounts(web3):
    """
    Return 6 accounts

    admin, bidder, hoster, validator1, validator2, validator3 = get_accounts()
    """
    return (
        DEPLOYER_ACCOUNT,
        web3.eth.accounts[0],
        web3.eth.accounts[1],
        web3.eth.accounts[2],
        web3.eth.accounts[3],
        web3.eth.accounts[4],
    )


def get_std_tx(from_addr):
    tx = {
        'from': from_addr,
    }
    return tx


def topic_signature(abi):
    if abi.type != 'event':
        return None
    args = ','.join([a.type for a in abi.inputs])
    sig = '{}({})'.format(abi.name, args)
    print("topic_signature: {}".format(sig))
    return Web3.sha3(text=sig)


def event_topics(web3contract):
    """ Process a Web3.py Contract and return a dict of event topic sigs """
    contract_abi = web3contract.abi
    events = []
    sigs = AttrDict({})

    for abi in contract_abi:
        if abi.type == 'event':
            sigs[abi.name] = topic_signature(abi)
    return sigs


def event_abi(contract_abi, name):
    """ Return the abi for a specific event """
    for abi in contract_abi:
        if abi.type == 'event' and abi.name == name:
            return abi
    return None


def get_event(web3contract, event_name, rcpt):
    print(rcpt)
    if len(rcpt.logs) < 1:
        return None

    for log in rcpt.logs:
        abi = event_abi(web3contract.abi, event_name)
        if not abi:
            continue
        evnt_data = get_event_data(abi, log)
        print('get_event evnt_data', evnt_data)
        return evnt_data
    return None


def has_event(web3contract, event_name, rcpt):
    print("rcpt", rcpt)
    abi = event_abi(web3contract.abi, event_name)
    sig = HexBytes(topic_signature(abi).hex())
    print("{} signature: {}".format(event_name, sig))
    for log in rcpt.logs:
        print("topics: {}".format(log.topics))
        if len(log.topics) > 0 and log.topics[0] == sig:
            return True
    return False

def normalize_event_filehash(fH):
    return '0x' + fH.hex()
