// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

/*
The MIT License (MIT)
Copyright (c) 2018 Murray Software, LLC.
Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:
The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
//solhint-disable max-line-length
//solhint-disable no-inline-assembly

// TODO: CloneFactory16

import {Address} from "@OpenZeppelin/utils/Address.sol";
import {Create2} from "@OpenZeppelin/utils/Create2.sol";

contract CloneFactoryEvents {
    event NewClone(
        address indexed target,
        bytes32 salt,
        address indexed immutable_owner,
        address clone
    );
}

contract CloneFactory is CloneFactoryEvents {
    using Address for address;

    /*
    Create a very lightweight "clone" contract that delegates all calls to the `target` contract.

    Some contracts (such as curve's vote locking contract) only allow access from EOAs and from DAO-approved smart wallets.
    Transfers would bypass Curve's time-locked votes since you could just sell your smart wallet.
    People could still sell their keys, but that is dangerous behavior that also applies to EOAs.
    We would like our ArgobytesProxy clones to qualify for these contracts and so the smart wallet CANNOT be transfered.

    To accomplish this, the clone has the `immutable_owner` address appended to the end of its code. This data cannot be changed.
    If the target contract uses ArgobytesAuth (or compatible) for authentication, then ownership of this clone *cannot* be transferred.

    We originally allowed setting an authority here, but that allowed for some shenanigans.
    It may cost slightly more, but a user will have to send a second transaction if they want to set an authority.
    */
    function createClone(
        address target,
        bytes32 salt,
        address immutableOwner
    ) public returns (address clone) {
        assembly {
            // Solidity manages memory in a very simple way: There is a “free memory pointer” at position 0x40 in memory.
            // If you want to allocate memory, just use the memory from that point on and update the pointer accordingly.
            let code := mload(0x40)

            // start of the contract (+20 bytes)
            // 10 of these bytes are for setup. the contract bytecode is 10 bytes shorter
            // the "0x41" below is the actual contract length
            mstore(
                code,
                0x3d604180600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            // target contract that the clone delegates all calls to (+20 bytes = 40)
            mstore(add(code, 0x14), shl(0x60, target))
            // end of the contract (+15 bytes = 55)
            mstore(
                add(code, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            // add the owner to the end (+20 bytes = 75)
            // 1. so we get a unique address from CREATE2
            // 2. so it can be used as an immutable owner
            mstore(add(code, 0x37), shl(0x60, immutableOwner))

            // deploy it
            clone := create2(0, code, 75, salt)
        }

        // revert if the contract was already deployed
        require(clone != address(0), "create2 failed");

        emit NewClone(target, salt, immutableOwner, clone);
    }

    function createClones(
        address target,
        bytes32[] calldata salts,
        address immutable_owner
    ) public {
        for (uint i = 0; i < salts.length; i++) {
            createClone(target, salts[i], immutable_owner);
        }
    }

    /* Check if a clone has already been created for the given arguments.*/
    function hasClone(
        address target,
        bytes32 salt,
        address immutableOwner
    ) public view returns (bool cloneExists, address cloneAddr) {
        bytes32 bytecodeHash;
        assembly {
            // Solidity manages memory in a very simple way: There is a “free memory pointer” at position 0x40 in memory.
            // If you want to allocate memory, just use the memory from that point on and update the pointer accordingly.
            let code := mload(0x40)

            // start of the contract (+20 bytes)
            // 10 of these bytes are for setup. the contract bytecode is 10 bytes shorter
            // the "0x41" below is the actual contract length
            mstore(
                code,
                0x3d604180600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            // target contract that the clone delegates all calls to (+20 bytes = 40)
            mstore(add(code, 0x14), shl(0x60, target))
            // end of the contract (+15 bytes = 55)
            mstore(
                add(code, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            // add the owner to the end (+20 bytes = 75)
            // 1. so we get a unique address from CREATE2
            // 2. so it can be used as an immutable owner
            mstore(add(code, 0x37), shl(0x60, immutableOwner))

            bytecodeHash := keccak256(code, 75)
        }

        // TODO: do this all here in assembly? the compiler should be smart enough to not have any savings doing that
        cloneAddr = Create2.computeAddress(salt, bytecodeHash);

        cloneExists = cloneAddr.isContract();
    }

    // TODO: how much cheaper is this than storing all the clone addresses in a mapping of bools?
    // TODO: if target is address(0), skip the target check?
    function isClone(address target, address query)
        public
        view
        returns (bool result, address owner)
    {
        assembly {
            let other := mload(0x40)

            // TODO: right now our contract is 45 bytes + 20 bytes for the owner address, but this will change if we use shorter addresses
            extcodecopy(query, other, 0, 65)

            // load 32 bytes (12 of the bytes will be ignored)
            // the last 20 bytes of this are the owner's address
            owner := mload(add(other, 33))

            let clone := add(other, 65)
            mstore(
                clone,
                0x363d3d373d3d3d363d7300000000000000000000000000000000000000000000
            )
            mstore(add(clone, 0xa), shl(0x60, target))
            mstore(
                add(clone, 0x1e),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            // we could copy the owner, but theres no real need
            // mstore(add(clone, 0x2d), owner)

            result := and(
                // check bytes 0 through 31
                eq(mload(clone), mload(other)),
                // check bytes 13 through 44
                // we don't care about checking the owner bytes (45 through 65)
                eq(mload(add(clone, 13)), mload(add(other, 13)))
            )
        }
    }
}
