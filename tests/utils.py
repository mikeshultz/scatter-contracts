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

def has_event(evnt_name, rcpt):
    print("rcpt", rcpt)
    assert false
