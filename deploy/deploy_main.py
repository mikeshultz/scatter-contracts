
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
    # assert slib.address is not None, "Deploy of Structures failed.  No address found"

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
        txhash = router.functions.set(web3.sha3(text='Env'), env.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "router set failed"

    ##
    # SLib Library
    ##
    SLib = contracts.get('SLib')
    assert SLib is not None, "Unable to get SLib contract"

    slib = SLib.deployed(links={
            'SafeMath': safeMath.address,
        })
    assert slib.address is not None, "Deploy of SLib failed.  No address found"
    if SLib.new_deployment is True:
        txhash = router.functions.set(web3.sha3(text='SLib'), slib.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "router set failed"

    ##
    # BidStore - Primary storage contract
    ##
    BidStore = contracts.get('BidStore')
    assert BidStore is not None, "Unable to get BidStore contract"

    store = BidStore.deployed(gas=int(6e6))
    assert store.address is not None, "Deploy of BidStore failed.  No address found"
    if BidStore.new_deployment is True:
        txhash = router.functions.set(web3.sha3(text='BidStore'), store.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "router set failed"

    ##
    # ChallengeStore - Primary storage contract
    ##
    ChallengeStore = contracts.get('ChallengeStore')
    assert ChallengeStore is not None, "Unable to get ChallengeStore contract"

    cstore = ChallengeStore.deployed(gas=int(6e6))
    assert cstore.address is not None, "Deploy of ChallengeStore failed.  No address found"
    if ChallengeStore.new_deployment is True:
        txhash = router.functions.set(web3.sha3(text='ChallengeStore'), cstore.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "router set failed"

    ##
    # DefenseStore - Primary storage contract
    ##
    DefenseStore = contracts.get('DefenseStore')
    assert DefenseStore is not None, "Unable to get DefenseStore contract"

    dstore = DefenseStore.deployed(gas=int(6e6))
    assert dstore.address is not None, "Deploy of DefenseStore failed.  No address found"
    if DefenseStore.new_deployment is True:
        txhash = router.functions.set(web3.sha3(text='DefenseStore'), dstore.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "router set failed"

    ##
    # Scatter - Primary contract
    ##
    Scatter = contracts.get('Scatter')
    assert Scatter is not None, "Unable to get Scatter contract"

    scatter = Scatter.deployed(router.address, links={
        'SafeMath': safeMath.address,
        'SLib': slib.address
        })
    assert scatter.address is not None, "Deploy of Scatter failed.  No address found"
    if Scatter.new_deployment is True:
        txhash = router.functions.set(web3.sha3(text='Scatter'), scatter.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "router set failed"

        txhash = store.functions.grant(scatter.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "grant failed"

        txhash = cstore.functions.grant(scatter.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "grant failed"

        txhash = dstore.functions.grant(scatter.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "grant failed"

    ##
    # PinStake - Contrat handling staking storage
    ##
    PinStake = contracts.get('PinStake')
    assert PinStake is not None, "Unable to get PinStake contract"

    pinStake = PinStake.deployed(router.address)
    assert pinStake.address is not None, "Deploy of PinStake failed.  No address found"

    if PinStake.new_deployment is True:
        txhash = router.functions.set(web3.sha3(text='PinStake'), pinStake.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "router set failed"

        txhash = pinStake.functions.grant(scatter.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "grant failed"

    # updateReferences in Scatter only if BidStore is a new deployment and Scatter is not
    if (PinStake.new_deployment is True or BidStore.new_deployment is True) \
            and not Scatter.new_deployment:
        txhash = scatter.functions.updateReferences().transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "updateReferences failed"

    ##
    # UserStore - UserStore storage for user registrations
    ##
    UserStore = contracts.get('UserStore')
    assert UserStore is not None, "Unable to get UserStore contract"

    userStore = UserStore.deployed()
    assert userStore.address is not None, "Deploy of UserStore failed.  No address found"

    if UserStore.new_deployment is True:
        txhash = router.functions.set(web3.sha3(text='UserStore'), userStore.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "router set failed"

    ##
    # Register - Contrat handling user registrations
    ##
    Register = contracts.get('Register')
    assert Register is not None, "Unable to get Register contract"

    register = Register.deployed(router.address)
    assert register.address is not None, "Deploy of Register failed.  No address found"

    if Register.new_deployment is True:
        txhash = router.functions.set(web3.sha3(text='Register'), register.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "router set failed"

    if Register.new_deployment is True or UserStore.new_deployment is True:
        txhash = userStore.functions.setWriter(register.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
            })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "setWriter failed"

    ##
    # PinChallenge - Contrat handling user registrations
    ##
    PinChallenge = contracts.get('PinChallenge')
    assert PinChallenge is not None, "Unable to get PinChallenge contract"

    pinChallenge = PinChallenge.deployed(router.address)
    assert pinChallenge.address is not None, "Deploy of PinChallenge failed.  No address found"

    if PinChallenge.new_deployment is True:
        txhash = router.functions.set(
            web3.sha3(text='PinChallenge'),
            pinChallenge.address
        ).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "router set failed"

        txhash = cstore.functions.grant(pinChallenge.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "grant failed"

        txhash = dstore.functions.grant(pinChallenge.address).transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
        })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "grant failed"

    if PinChallenge.new_deployment is True or Scatter.new_deployment is True:
        txhash = scatter.functions.updateReferences().transact({
            'from': deployer_account,
            'gas': int(1e5),
            'gasPrice': GAS_PRICE,
            })
        receipt = web3.eth.waitForTransactionReceipt(txhash)
        assert receipt.status == 1, "router set failed"
