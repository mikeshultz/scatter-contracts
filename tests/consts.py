from web3 import Web3

DEPLOYER_ACCOUNT='0x208B6e328105148Baf90C5d6a8F65A0accd17A95'

BID_CONTRACT_NAME = 'SkatterBid'
ENV_CONTRACT_NAME = 'Env'

DURATION_1 = 60*60*24*14 # 2 weeks
FILE_HASH_1 = '0x16c55d9e9ca5b673cafaa112195a5ad78ceb104e612ff2afbf34c233d6e7482b'
FILE_SIZE_1 = 1024

UINT_HASH_1 = Web3.sha3(text='whatever')
UINT_VAL_1 = 123

STR_HASH_1 = Web3.sha3(text='imastring')
STR_VAL_1 = 'imavalue'
