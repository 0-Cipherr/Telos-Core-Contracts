import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TelosVault {
    uint256 totalAssets;
    address[] authorized;
    uint32 endpointId;
    uint256 vaultId;
    constructor(
        uint32 _endpointId,
        uint256 _vaultId,
        address _creator,
        address _agent
    ) {
        endpointId = _endpintId;
        totalAssets = 0;
        authorized.push(_creator);
        authorized.push(_agent);
        authorized.push(msg.sender); //the frontend wallet i got
        vaultId = _vaultId;
    }

    function deposit(uint256 _amount) public payable {
        require(_amount == msg.value, "notenough!");

        totalAssets += _amount;
    }

    function addAuhtorizd(address _newAuth) public {
        authorized.push(_newAuth);
    }

    function withdraw(address _reciever, uint256 _amount) public {
        totalAssets -= _amount;
        address(payable(_reciever)).call{value: _amount}("");
    }

    function bridgeQuote() public view {}

    function bridge() public {}
}
