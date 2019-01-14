
def main(assertions, web3, contracts, deployer_account, network):
    assert contracts is not None
    assert deployer_account is not None
    assert web3 is not None
    assert network is not None

    GAS_PRICE = int(3e9)
    
    deployer_balance = web3.eth.getBalance(deployer_account)

    if network in ('dev', 'test'):
        # If this is the test network, make sure our deployment account is funded
        if deployer_balance == 0:
            fund_value = int(1e18)
            tx = web3.eth.sendTransaction({
                'from': web3.eth.accounts[0], # The pre-funded account in ganace-cli
                'to': deployer_account,
                'value': fund_value,
                'gasPrice': GAS_PRICE,
                })
            receipt = web3.eth.waitForTransactionReceipt(tx)
            assert receipt.status == 1, "Funding deployer_account failed"
            deployer_balance = web3.eth.getBalance(deployer_account)
            assert deployer_balance >= fund_value, "Funding of deployer_account too low"
    else:
        # Make sure deployer account has at least 0.5 ether
        assert deployer_balance < int(5e17), "deployer account needs to be funded"

    print("web3.net.version: {}".format(web3.net.version))
    print("deployer_account: {}".format(deployer_account))
    print("deployer_balance: {} Ether".format(deployer_balance / 1e18))
    #Test = contracts.get('Test')
    print("contracts: ", contracts)

    ##
    # Structures Library
    ##
    # Structures = contracts.get('Structures')
    # assert Structures is not None, "Unable to get Structures contract"

    # structures = Structures.deployed()
    # assert rewards.address is not None, "Deploy of Structures failed.  No address found"

    ##
    # SafeMath Library
    ##
    SafeMath = contracts.get('SafeMath')
    assert SafeMath is not None, "Unable to get ScatterRewards contract"

    safeMath = SafeMath.deployed()
    assert safeMath.address is not None, "SafeMath was not deployed or is unknown"

    ##
    # Env state contract
    ##
    Env = contracts.get('Env')
    assert Env is not None, "Unable to get Env contract"
    env = Env.deployed()
    assert env.address is not None, "Deploy of Env failed.  No address found"

    ##
    # ScatterRewards Library
    ##
    ScatterRewards = contracts.get('ScatterRewards')
    assert ScatterRewards is not None, "Unable to get ScatterRewards contract"

    rewards = ScatterRewards.deployed(links={
            'SafeMath': safeMath.address,
        })
    assert rewards.address is not None, "Deploy of ScatterRewards failed.  No address found"

    ##
    # BidStore - Primary storage contract
    ##
    BidStore = contracts.get('BidStore')
    assert BidStore is not None, "Unable to get BidStore contract"

    store = BidStore.deployed(deployer_account, gas=int(6e6))
    assert store.address is not None, "Deploy of BidStore failed.  No address found"

    ##
    # ScatterBid - Primary contract
    ##
    ScatterBid = contracts.get('ScatterBid')
    assert ScatterBid is not None, "Unable to get ScatterBid contract"

    sb = ScatterBid.deployed(env.address, store.address, links={
        'SafeMath': safeMath.address,
        'ScatterRewards': rewards.address
        })
    assert sb.address is not None, "Deploy of ScatterBid failed.  No address found"

    store_sb_address = store.functions.scatterBidAddress().call()
    if store_sb_address != sb.address:
        store.functions.setScatterBid(sb.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
            })

    return True
