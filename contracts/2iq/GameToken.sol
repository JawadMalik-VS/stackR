// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title GameToken
 * @dev ERC20 Token with a max supply and admin-controlled minting.
 */
contract GameToken is Context, Ownable, ERC20 {
    // Admin address
    address private admin;
    // Set max circulation of tokens: 100000000000000000000
    uint256 private _maxSupply = 100 * (10 ** uint256(decimals()));
    uint256 private _unit = 10 ** uint256(decimals());

    // Only admin account can unlock escrow
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can mint tokens.");
        _;
    }

    /**
     * @dev Returns max supply of the token.
     */
    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    /**
     * @dev Returns single unit of account.
     */
    function unit() public view returns (uint256) {
        return _unit;
    }

    /**
     * @dev Constructor that gives `_msgSender()` all of existing tokens.
     * Passes `name`, `symbol`, and `initialOwner` to the respective constructors.
     */
    constructor(string memory name, string memory symbol) 
        ERC20(name, symbol) 
        Ownable(msg.sender) 
    {
        admin = msg.sender;
        // Initialize circulation
        mint();
    }

    /**
     * @dev Mint the maximum supply to the admin.
     */
    function mint() public onlyAdmin {
        _mint(msg.sender, _maxSupply);
    }

    /**
     * @dev Override the approve function to allow default max approval.
     */
    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        address owner = _msgSender();
        amount = _maxSupply; // Set to max supply by default
        _approve(owner, spender, amount);
        return true;
    }
}
