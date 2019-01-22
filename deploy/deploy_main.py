
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
                'from': web3.eth.accounts[0],  # The pre-funded account in ganace-cli
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
    print("contracts: ", contracts)

    ##
    # Router
    ##
    Router = contracts.get('Router')
    assert Router is not None

    router = Router.deployed()
    assert router.address is not None, "No address on Router contract object"

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
    assert SafeMath is not None, "Unable to get SafeMath contract"

    safeMath = SafeMath.deployed()
    assert safeMath.address is not None, "SafeMath was not deployed or is unknown"

    ##
    # Env state contract
    ##
    Env = contracts.get('Env')
    assert Env is not None, "Unable to get Env contract"
    env = Env.deployed()
    assert env.address is not None, "Deploy of Env failed.  No address found"
    if Env.new_deployment is True:
        router.functions.set(web3.sha3(text='Env'), env.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })

    ##
    # Rewards Library
    ##
    Rewards = contracts.get('Rewards')
    assert Rewards is not None, "Unable to get Rewards contract"

    rewards = Rewards.deployed(links={
            'SafeMath': safeMath.address,
        })
    assert rewards.address is not None, "Deploy of Rewards failed.  No address found"
    if Rewards.new_deployment is True:
        router.functions.set(web3.sha3(text='Rewards'), rewards.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })

    ##
    # BidStore - Primary storage contract
    ##
    BidStore = contracts.get('BidStore')
    assert BidStore is not None, "Unable to get BidStore contract"

    store = BidStore.deployed(router.address, gas=int(6e6))
    assert store.address is not None, "Deploy of BidStore failed.  No address found"
    if BidStore.new_deployment is True:
        router.functions.set(web3.sha3(text='BidStore'), store.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })

    ##
    # Scatter - Primary contract
    ##
    Scatter = contracts.get('Scatter')
    assert Scatter is not None, "Unable to get Scatter contract"

    sb = Scatter.deployed(router.address, links={
        'SafeMath': safeMath.address,
        'Rewards': rewards.address
        })
    assert sb.address is not None, "Deploy of Scatter failed.  No address found"
    if Scatter.new_deployment is True:
        router.functions.set(web3.sha3(text='Scatter'), sb.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        store.functions.updateReferences().transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })

    # updateReferences in Scatter only if BidStore is a new deployment and Scatter is not
    if BidStore.new_deployment is True and not Scatter.new_deployment:
        sb.functions.updateReferences().transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })

    store_sb_address = store.functions.scatterAddress().call()
    if store_sb_address != sb.address:
        set_hash = store.functions.setScatter(sb.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
            })
        set_receipt = web3.eth.waitForTransactionReceipt(set_hash)
        assert set_receipt.status == 1

    ##
    # UserStore - UserStore storage for user registrations
    ##
    UserStore = contracts.get('UserStore')
    assert UserStore is not None, "Unable to get UserStore contract"

    userStore = UserStore.deployed()
    assert userStore.address is not None, "Deploy of UserStore failed.  No address found"

    if UserStore.new_deployment is True:
        router.functions.set(web3.sha3(text='UserStore'), userStore.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })

    ##
    # Register - Contrat handling user registrations
    ##
    Register = contracts.get('Register')
    assert Register is not None, "Unable to get Register contract"

    register = Register.deployed(router.address)
    assert register.address is not None, "Deploy of Register failed.  No address found"

    if Register.new_deployment is True:
        router.functions.set(web3.sha3(text='Register'), register.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })

    if Register.new_deployment is True or UserStore.new_deployment is True:
        userStore.functions.setWriter(register.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
            })

    return True
