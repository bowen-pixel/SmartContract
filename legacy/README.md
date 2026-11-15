# Historical reference

`SmartContract.sol` is the earlier Solidity 0.4.x `SimplePaymentChannel` based on [Steve Marx's tutorial](https://programtheblockchain.com/posts/2018/02/23/writing-a-simple-payment-channel/). It was moved here without rewriting its behavior. The signature-prefix typo in the tutorial had already been corrected when this file was first added.

It is excluded from `channel-lab/` builds. It relies on historical `selfdestruct` semantics and should not be deployed as the modern implementation. Compare it with the explicit states, EIP-712 signatures, and payout credits in the modern contracts. [EIP-6780](https://eips.ethereum.org/EIPS/eip-6780) describes the changed deletion behavior.
