
def main(web3, contracts, deployer_account, network):
    assert contracts is not None
    assert deployer_account is not None
    assert web3 is not None
    assert network is not None
    
    deployer_balance = web3.eth.getBalance(deployer_account)

    if network in ('dev', 'test'):
        # If this is the test network, make sure our deployment account is funded
        if deployer_balance == 0:
            fund_value = int(1e18)
            tx = web3.eth.sendTransaction({
                'from': web3.eth.accounts[0], # The pre-funded account in ganace-cli
                'to': deployer_account,
                'value': fund_value,
                'gasPrice': int(3e9),
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
    # SafeMath Library
    ##
    SafeMath = contracts.get('SafeMath')
    assert SafeMath is not None, "Unable to get SkatterRewards contract"

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
    # SkatterRewards Library
    ##
    SkatterRewards = contracts.get('SkatterRewards')
    assert SkatterRewards is not None, "Unable to get SkatterRewards contract"

    rewards = SkatterRewards.deployed(links={
            'SafeMath': safeMath.address,
        })
    assert rewards.address is not None, "Deploy of SkatterRewards failed.  No address found"

    SkatterBid = contracts.get('SkatterBid')
    assert SkatterBid is not None, "Unable to get SkatterBid contract"

    sb = SkatterBid.deployed(env.address, links={
        'SafeMath': safeMath.address,
        'SkatterRewards': rewards.address
        })
    assert sb.address is not None, "Deploy of SkatterBid failed.  No address found"

    return True
