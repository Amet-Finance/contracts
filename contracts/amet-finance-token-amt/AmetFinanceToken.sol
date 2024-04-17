// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import {ERC20, ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @custom:security-contact hello@amet.finance
contract AmetFinanceToken is ERC20, ERC20Pausable, Ownable2Step, ERC20Permit {
    constructor()
    ERC20("Amet Finance Token", "AMT")
    Ownable(msg.sender)
    ERC20Permit("Amet Finance Token")
    {
        _mint(msg.sender, 1000000000000 * 10 ** decimals());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
    internal
    override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}
