pragma solidity >=0.5.2 <0.6.0;

import "./lib/Owned.sol";
import "./interface/IHashStore.sol";
import "./interface/IRouter.sol";
import "./storage/Env.sol";


contract Register is Owned {  /// interface: IRegister

    IHashStore public userStore;
    IRouter public router;
    Env public env;

    // solhint-disable-next-line max-line-length
    bytes32 private constant EMPTY_IPFS_FILE = 0xbfccda787baba32b59c78450ac3d20b633360b43992c77289f9ed46d843561e6;
    bytes32 private constant USER_STORE_HASH = keccak256("UserStore");

    modifier notBanned() { require(!env.isBanned(msg.sender), "banned"); _; }

    constructor (address _router) public
    {
        router = IRouter(_router);
        updateReferences();
    }

    function getUserFile(address _user) external view returns (bytes32)
    {
        return userStore.getBytes32(keccak256(abi.encode(_user)));
    }

    function register(address _user, bytes32 ipfsUserFile) public notBanned
    {
        require(_user != address(0), "zero address");
        require(ipfsUserFile != EMPTY_IPFS_FILE, "empty");
        require(ipfsUserFile != bytes32(0), "zero file");

        userStore.setBytes32(keccak256(abi.encode(_user)), ipfsUserFile);

    }

    /** updateReferences()
     *  @dev Using the router, update all the addresses
     *  @return bool If anything was updated
     */
    function updateReferences() public ownerOnly returns (bool)
    {
        address newStoreAddress = router.get(USER_STORE_HASH);
        if (newStoreAddress != address(userStore))
        {
            userStore = IHashStore(newStoreAddress);
            return true;
        }
        return false;
    }
}