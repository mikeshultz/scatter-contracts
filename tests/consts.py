from web3 import Web3

DEPLOYER_ACCOUNT = '0x208B6e328105148Baf90C5d6a8F65A0accd17A95'
ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
ADDRESS_1 = '0x16c55d9E9CA5b673cAfAA112195a5ad78CeB104E'

MAIN_CONTRACT_NAME = 'Scatter'
STORE_CONTRACT_NAME = 'BidStore'
ENV_CONTRACT_NAME = 'Env'
ROUTER_CONTRACT_NAME = 'Router'

STD_GAS = int(1e5)
STD_GAS_PRICE = int(3e9)

DURATION_1 = 60*60*24*14  # 2 weeks
DURATION_2 = 60*60*24*31  # 31 days
FILE_HASH_1 = '0x16c55d9e9ca5b673cafaa112195a5ad78ceb104e612ff2afbf34c233d6e7482b'
FILE_SIZE_1 = 1024
FILE_HASH_2 = '0xbf5c0efb83b4a3762058cfdf011d03d34c11d9721ad3e7ffc4b53d4287ddcc1b'
FILE_SIZE_2 = 4096
EMPTY_FILE_HASH = '0xbfccda787baba32b59c78450ac3d20b633360b43992c77289f9ed46d843561e6'

UINT_HASH_1 = Web3.sha3(text='whatever')
UINT_VAL_1 = 123

STR_HASH_1 = Web3.sha3(text='imastring')
STR_VAL_1 = 'imavalue'

ENV_ACCEPT_WAIT = Web3.sha3(text='acceptHoldDuration')
ENV_DEFAULT_MIN_VALIDATIONS = Web3.sha3(text='defaultMinValidations')
ENV_MIN_DURATION = Web3.sha3(text='minDuration')
ENV_MIN_BID = Web3.sha3(text='minBid')
