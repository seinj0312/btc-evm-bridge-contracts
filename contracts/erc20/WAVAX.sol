pragma solidity 0.8.0;

import "./interfaces/IWAVAX.sol";
import "../libraries/SafeMath.sol";
import "./ERC20.sol";
import "hardhat/console.sol";

contract WAVAX is ERC20 {
    // using SafeMath for uint;

    constructor(string memory _name, string memory _symbol)
    ERC20(_name, _symbol, 0) public {}

    function deposit() external payable {
        require(msg.value > 0);
        _mint(_msgSender(), msg.value);
    }

    function withdraw(uint value) external {
        require(balanceOf(_msgSender()) >= value, "Balance is not sufficient");
        _burn(_msgSender(), value);
        address payable recipient = payable(_msgSender());
        recipient.send(value);
    }
}
