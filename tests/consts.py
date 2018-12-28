from web3 import Web3

DEPLOYER_ACCOUNT='0x208B6e328105148Baf90C5d6a8F65A0accd17A95'

BID_CONTRACT_NAME = 'SkatterBid'
ENV_CONTRACT_NAME = 'Env'

DURATION_1 = 60*60*24*14 # 2 weeks
DURATION_2 = 60*60*24*31 # 31 days
FILE_HASH_1 = '0x16c55d9e9ca5b673cafaa112195a5ad78ceb104e612ff2afbf34c233d6e7482b'
FILE_SIZE_1 = 1024
FILE_HASH_2 = '0xbf5c0efb83b4a3762058cfdf011d03d34c11d9721ad3e7ffc4b53d4287ddcc1b'
FILE_SIZE_2 = 4096

UINT_HASH_1 = Web3.sha3(text='whatever')
UINT_VAL_1 = 123

STR_HASH_1 = Web3.sha3(text='imastring')
STR_VAL_1 = 'imavalue'

ENV_ACCEPT_WAIT = Web3.sha3(text='acceptHoldDuration')
ENV_DEFAULT_MIN_VALIDATIONS = Web3.sha3(text='defaultMinValidations')
