pragma solidity ^0.4.20;

// Educational implementation based on Steve Marx's payment-channel tutorial:
// https://programtheblockchain.com/posts/2018/02/23/writing-a-simple-payment-channel/
// Targets the tutorial's Solidity 0.4.x and historical EVM behavior.
// Not suitable for deployment on current networks: this design relies on
// selfdestruct deleting contract code, which modern EVMs no longer guarantee.
contract SimplePaymentChannel {
    address public sender;
    address public recipient;
    uint256 public expiration;

    // Deploy with ether to fund the channel; duration is measured in seconds.
    function SimplePaymentChannel(address _recipient, uint256 duration)
        public
        payable
    {
        sender = msg.sender;
        recipient = _recipient;
        expiration = now + duration;
    }

    // Only the recipient may redeem a sender-signed cumulative amount in wei.
    function close(uint256 amount, bytes signature) public {
        require(msg.sender == recipient);
        require(isValidSignature(amount, signature));
        recipient.transfer(amount);
        selfdestruct(sender);
    }

    function extend(uint256 newExpiration) public {
        require(msg.sender == sender);
        require(newExpiration > expiration);
        expiration = newExpiration;
    }

    // Anyone may trigger expiry, but the funds always return to the sender.
    function claimTimeout() public {
        require(now >= expiration);
        selfdestruct(sender);
    }

    function isValidSignature(uint256 amount, bytes signature)
        internal
        view
        returns (bool)
    {
        bytes32 digest = prefixed(keccak256(this, amount));
        return recoverSigner(digest, signature) == sender;
    }

    function recoverSigner(bytes32 digest, bytes signature)
        internal
        pure
        returns (address)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = splitSignature(signature);
        return ecrecover(digest, v, r, s);
    }

    function splitSignature(bytes signature)
        internal
        pure
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        require(signature.length == 65);
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
    }

    function prefixed(bytes32 digest) internal pure returns (bytes32) {
        // Standard personal_sign prefix; fixes the extra spaces in the
        // tutorial's full-source snippet so off-chain signatures verify.
        return keccak256("\x19Ethereum Signed Message:\n32", digest);
    }
}
