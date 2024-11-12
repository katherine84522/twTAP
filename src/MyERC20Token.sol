// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MyERC20Token is ERC20, AccessControl {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(uint256 initialSupply) ERC20("Katherine the Great", "KTG"){

        

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _mint(msg.sender, initialSupply * 10 ** decimals());

    }

    function mint(address to, uint256 amount) public {

        _mint(to, amount);

    }

}