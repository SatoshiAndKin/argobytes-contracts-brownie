// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {Create2} from "@OpenZeppelin/utils/Create2.sol";

import {LiquidGasTokenUser} from "contracts/LiquidGasTokenUser.sol";

import {Diamond} from "./Diamond.sol";
import {DiamondCutter} from "./DiamondCutter.sol";
import {DiamondLoupe} from "./DiamondLoupe.sol";
import {
    ILiquidGasToken
} from "contracts/interfaces/liquidgastoken/ILiquidGasToken.sol";

// TODO: cute name like DiamondMine?
contract DiamondCreator is LiquidGasTokenUser {
    // TODO: better to hard code this or pass as calldata?
    // address constant LGT = 0x000000000000c1cb11d5c062901f32d06248ce48;

    // use CREATE2 to deploy a diamond with an efficient address
    // use LiquidGasToken to save some gas fees
    constructor(
        address gas_token,
        bytes32 cutter_salt,
        bytes32 loupe_salt,
        bytes32 diamond_salt
    ) public payable {
        uint256 initial_gas = initialGas(gas_token);

        // TODO: have an alternative DiamondCreator contract that uses pre-deployed addresses for cutter/loupe
        DiamondCutter cutter = new DiamondCutter{salt: cutter_salt}();
        DiamondLoupe loupe = new DiamondLoupe{salt: loupe_salt}();

        // any ETH left in this Creator contract will be forwarded to the diamond via selfdestruct
        Diamond diamond = new Diamond{salt: diamond_salt}(
            address(cutter),
            address(loupe)
        );

        // transfer admin role from `this` to `msg.sender`
        bytes32 admin_role = diamond.DEFAULT_ADMIN_ROLE();

        diamond.grantRole(admin_role, msg.sender);
        // TODO: since we selfdestruct, do we really need renounceRole? probably safest to do it
        diamond.renounceRole(admin_role, address(this));

        if (initial_gas > 0) {
            // TODO: since we are going to self destruct and get 200k back, we need to tweak how much we free. think about this more
            freeGasTokens(gas_token, initial_gas + 420000);

            // transfer any remaining gas tokens
            uint256 gas_token_balance = ILiquidGasToken(gas_token).balanceOf(
                address(this)
            );

            if (gas_token_balance > 0) {
                // i don't think its worth checking this return
                ILiquidGasToken(gas_token).transfer(
                    address(diamond),
                    gas_token_balance
                );
            }
        }

        // selfdestruct for the gas refund (~200k gas)
        // this forwards any ETH in this contract to the diamond
        // this must be last!
        selfdestruct(address(diamond));
    }
}
