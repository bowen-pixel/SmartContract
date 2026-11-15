# Storage example: reading the contract

Code: [SimpleStorage.sol](../src/SimpleStorage.sol). Evidence: [SimpleStorage.t.sol](../test/SimpleStorage.t.sol).

## Takeaways

A deployed contract combines persistent data with callable functions. This example stores one integer. Anyone can replace it. Persistence means the value survives later calls; it does not mean the value cannot be changed.

## Expression by expression

| Expression | Explanation |
| --- | --- |
| SPDX comment | License for this new implementation; has no runtime effect |
| `pragma solidity 0.8.30` | Requires this compiler, but does not install it |
| `contract SimpleStorage` | Defines the contract type |
| `uint256 private storedData` | Persistent unsigned 256-bit number, initially zero |
| `set(uint256 newValue)` | Takes a number supplied by the caller |
| `external` | Exposes an external entry point |
| `storedData = newValue` | Assigns the argument to persistent storage |
| `get() external view returns (uint256)` | Reads state without modifying it and returns one number |
| `return storedData` | Sends the current value back to the caller |
| Braces and semicolons | Braces delimit bodies; semicolons terminate statements |

`uint` is an alias for `uint256`. Unsigned integers cannot represent negative values. A function parameter is local to that call; the state variable persists. `private` is Solidity access control, not encryption: blockchain storage can be inspected. The page uses `public` functions; this implementation uses `external` for externally called entry points.

## Trace and tests

Deploy -> read 0. Alice sets 42 -> read 42. Bob sets 99 -> read 99, even when Alice reads it. There is one shared number, not one number per user. `test_LatestCallerOverwritesValue` demonstrates this behavior. The fuzz test writes an arbitrary uint256 and checks that reading returns it.

Run `forge test --match-contract SimpleStorageTest -vv`. To understand assertion failure, temporarily expect 43 after setting 42, observe the failure, then restore the test. That failing experiment is not left in the committed suite.

Question to check understanding: what access check would be necessary if only a designated owner should overwrite the number?

Source: [Solidity storage example](https://docs.soliditylang.org/en/v0.8.30/introduction-to-smart-contracts.html#storage-example).
