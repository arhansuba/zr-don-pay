// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library SignTypes {
    struct ZrKeyReqParams {
        bytes32 walletTypeId;
    }

    struct ZrKeyResParams {
        bytes32 walletTypeId;
        address owner;
        uint256 walletIndex;
        string publicKey;
        bytes authSignature;
    }

    struct ZrSignParams {
        bytes32 walletTypeId;
        uint256 walletIndex;
        bytes32 dstChainId;
        bytes payload; // For `zrSignHash`, this would be the hash converted to bytes
        bool broadcast; // Relevant for `zrSignTx`, must be ignored for others
    }

    struct SigReqParams {
        bytes32 walletTypeId;
        uint256 walletIndex;
        bytes32 dstChainId;
        bytes payload;
        address owner;
        uint8 isHashDataTx;
        bool broadcast;
    }

    struct SignResParams {
        uint256 traceId;
        bytes signature;
        bool broadcast;
        bytes authSignature;
    }
}

library Lib_RLPWriter {
    /**********************
     * Internal Functions *
     **********************/

    /**
     * RLP encodes a byte string.
     * @param _in The byte string to encode.
     * @return The RLP encoded string in bytes.
     */
    function writeBytes(bytes memory _in) internal pure returns (bytes memory) {
        bytes memory encoded;

        if (_in.length == 1 && uint8(_in[0]) < 128) {
            encoded = _in;
        } else {
            encoded = abi.encodePacked(_writeLength(_in.length, 128), _in);
        }

        return encoded;
    }

    /**
     * RLP encodes a list of RLP encoded byte byte strings.
     * @param _in The list of RLP encoded byte strings.
     * @return The RLP encoded list of items in bytes.
     */
    function writeList(bytes[] memory _in)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory list = _flatten(_in);
        return abi.encodePacked(_writeLength(list.length, 192), list);
    }

    /**
     * RLP encodes a string.
     * @param _in The string to encode.
     * @return The RLP encoded string in bytes.
     */
    function writeString(string memory _in)
        internal
        pure
        returns (bytes memory)
    {
        return writeBytes(bytes(_in));
    }

    /**
     * RLP encodes an address.
     * @param _in The address to encode.
     * @return The RLP encoded address in bytes.
     */
    function writeAddress(address _in) internal pure returns (bytes memory) {
        return writeBytes(abi.encodePacked(_in));
    }

    /**
     * RLP encodes a uint.
     * @param _in The uint256 to encode.
     * @return The RLP encoded uint256 in bytes.
     */
    function writeUint(uint256 _in) internal pure returns (bytes memory) {
        return writeBytes(_toBinary(_in));
    }

    /**
     * RLP encodes a bool.
     * @param _in The bool to encode.
     * @return The RLP encoded bool in bytes.
     */
    function writeBool(bool _in) internal pure returns (bytes memory) {
        bytes memory encoded = new bytes(1);
        encoded[0] = (_in ? bytes1(0x01) : bytes1(0x80));
        return encoded;
    }

    /*********************
     * Private Functions *
     *********************/

    /**
     * Encode the first byte, followed by the `len` in binary form if `length` is more than 55.
     * @param _len The length of the string or the payload.
     * @param _offset 128 if item is string, 192 if item is list.
     * @return RLP encoded bytes.
     */
    function _writeLength(uint256 _len, uint256 _offset)
        private
        pure
        returns (bytes memory)
    {
        bytes memory encoded;

        if (_len < 56) {
            encoded = new bytes(1);
            encoded[0] = bytes1(uint8(_len) + uint8(_offset));
        } else {
            uint256 lenLen;
            uint256 i = 1;
            while (_len / i != 0) {
                lenLen++;
                i *= 256;
            }

            encoded = new bytes(lenLen + 1);
            encoded[0] = bytes1(uint8(lenLen) + uint8(_offset) + 55);
            for (i = 1; i <= lenLen; i++) {
                encoded[i] = bytes1(uint8((_len / (256**(lenLen - i))) % 256));
            }
        }

        return encoded;
    }

    /**
     * Encode integer in big endian binary form with no leading zeroes.
     * @notice TODO: This should be optimized with assembly to save gas costs.
     * @param _x The integer to encode.
     * @return RLP encoded bytes.
     */
    function _toBinary(uint256 _x) internal pure returns (bytes memory) {
        bytes memory b = abi.encodePacked(_x);

        uint256 i = 0;
        for (; i < 32; i++) {
            if (b[i] != 0) {
                break;
            }
        }

        bytes memory res = new bytes(32 - i);
        for (uint256 j = 0; j < res.length; j++) {
            res[j] = b[i++];
        }

        return res;
    }

    /**
     * Copies a piece of memory to another location.
     * @notice From: https://github.com/Arachnid/solidity-stringutils/blob/master/src/strings.sol.
     * @param _dest Destination location.
     * @param _src Source location.
     * @param _len Length of memory to copy.
     */
    function _memcpy(
        uint256 _dest,
        uint256 _src,
        uint256 _len
    ) private pure {
        uint256 dest = _dest;
        uint256 src = _src;
        uint256 len = _len;

        for (; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        uint256 mask;
        unchecked {
            mask = 256**(32 - len) - 1;
        }
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    /**
     * Flattens a list of byte strings into one byte string.
     * @notice From: https://github.com/sammayo/solidity-rlp-encoder/blob/master/RLPEncode.sol.
     * @param _list List of byte strings to flatten.
     * @return The flattened byte string.
     */
    function _flatten(bytes[] memory _list)
        private
        pure
        returns (bytes memory)
    {
        if (_list.length == 0) {
            return new bytes(0);
        }

        uint256 len;
        uint256 i = 0;
        for (; i < _list.length; i++) {
            len += _list[i].length;
        }

        bytes memory flattened = new bytes(len);
        uint256 flattenedPtr;
        assembly {
            flattenedPtr := add(flattened, 0x20)
        }

        for (i = 0; i < _list.length; i++) {
            bytes memory item = _list[i];

            uint256 listPtr;
            assembly {
                listPtr := add(item, 0x20)
            }

            _memcpy(flattenedPtr, listPtr, item.length);
            flattenedPtr += _list[i].length;
        }

        return flattened;
    }
}

interface IZrSign {
    function zrKeyReq(SignTypes.ZrKeyReqParams calldata params)
        external
        payable;

    function zrSignHash(SignTypes.ZrSignParams calldata params)
        external
        payable;

    function zrSignData(SignTypes.ZrSignParams calldata params)
        external
        payable;

    function zrSignTx(SignTypes.ZrSignParams calldata params) external payable;

    function isWalletTypeSupported(bytes32 walletTypeId)
        external
        view
        returns (bool);

    function isChainIdSupported(bytes32 walletTypeId, bytes32 chainId)
        external
        view
        returns (bool);

    function getTraceId() external view returns (uint256);

    function getBaseFee() external view returns (uint256);

    function getNetworkFee() external view returns (uint256);

    function getZrKeys(bytes32 walletTypeId, address owner)
        external
        view
        returns (string[] memory);

    function getZrKey(
        bytes32 walletTypeId,
        address owner,
        uint256 index
    ) external view returns (string memory);
}

// Abstract contract for zrSIgn connections
abstract contract ZrSignConnect {
    // Use the RLPWriter library for various types
    using Lib_RLPWriter for address;
    using Lib_RLPWriter for uint256;
    using Lib_RLPWriter for bytes;
    using Lib_RLPWriter for bytes[];

    // Address of the ZrSign contract
    address internal constant zrSign =
        payable(address(0x8F309C9550D0d69C3f9b8d7BCdC7C93B05Cd089e)); // ZrSign Sepolia address

    // The wallet type for EVM-based wallets
    bytes32 internal constant EVMWalletType =
        0xe146c2986893c43af5ff396310220be92058fb9f4ce76b929b80ef0d5307100a;

    // Request a new EVM wallet
    // This function uses the ZrSign contract to request a new public key for the EVM wallet type
    function requestNewEVMWallet() public virtual {
        uint256 _fee = IZrSign(zrSign).getBaseFee();
        // Prepare the parameters for the key request
        SignTypes.ZrKeyReqParams memory params = SignTypes.ZrKeyReqParams({
            walletTypeId: EVMWalletType
        });
        IZrSign(zrSign).zrKeyReq{value: _fee}(params);
    }

    // Request a signature for a specific hash
    // This function uses the ZrSign contract to request a signature for a specific hash
    // Parameters:
    // - walletTypeId: The ID of the wallet type associated with the hash
    // - fromAccountIndex: The index of the public key to be used for signing
    // - dstChainId: The ID of the destination chain
    // - payloadHash: The hash of the payload to be signed
    function reqSignForHash(
        bytes32 walletTypeId,
        uint256 walletIndex,
        bytes32 dstChainId,
        bytes32 payloadHash
    ) internal virtual {
        uint256 _fee = calculateFeeForSign(abi.encode(payloadHash));
        SignTypes.ZrSignParams memory params = SignTypes.ZrSignParams({
            walletTypeId: walletTypeId,
            walletIndex: walletIndex,
            dstChainId: dstChainId,
            payload: abi.encodePacked(payloadHash),
            broadcast: false // Not used in this context
        });

        IZrSign(zrSign).zrSignHash{value: _fee}(params);
    }

    // Request a signature for a specific data payload
    // This function uses the ZrSign contract to request a signature for a specific data payload
    // Parameters:
    // - walletTypeId: The ID of the wallet type associated with the data payload
    // - fromAccountIndex: The index of the public key to be used for signing
    // - dstChainId: The ID of the destination chain
    // - payload: The data payload to be signed
    function reqSignForData(
        bytes32 walletTypeId,
        uint256 walletIndex,
        bytes32 dstChainId,
        bytes memory payload
    ) internal virtual {
        uint256 _fee = calculateFeeForSign(abi.encode(payload));
        SignTypes.ZrSignParams memory params = SignTypes.ZrSignParams({
            walletTypeId: walletTypeId,
            walletIndex: walletIndex,
            dstChainId: dstChainId,
            payload: payload,
            broadcast: false
        });
        IZrSign(zrSign).zrSignData{value: _fee}(params);
    }

    // Request a signature for a transaction
    // This function uses the zrSIgn contract to request a signature for a transaction
    // Parameters:
    // - walletTypeId: The ID of the wallet type associated with the transaction
    // - fromAccountIndex: The index of the account from which the transaction will be sent
    // - chainId: The ID of the chain on which the transaction will be executed
    // - payload: The RLP-encoded transaction data
    // - broadcast: A flag indicating whether the transaction should be broadcasted immediately

    function reqSignForTx(
        bytes32 walletTypeId,
        uint256 walletIndex,
        bytes32 dstChainId,
        bytes memory payload,
        bool broadcast
    ) internal virtual {
        uint256 _fee = calculateFeeForSign(abi.encode(payload));
        SignTypes.ZrSignParams memory params = SignTypes.ZrSignParams({
            walletTypeId: walletTypeId,
            walletIndex: walletIndex,
            dstChainId: dstChainId,
            payload: payload,
            broadcast: broadcast
        });

        IZrSign(zrSign).zrSignTx{value: _fee}(params);
    }

    function calculateFeeForSign(bytes memory payload)
        public
        view
        returns (uint256)
    {
        uint256 networkFee = payload.length * IZrSign(zrSign).getNetworkFee();
        uint256 totalFee = IZrSign(zrSign).getBaseFee() + networkFee;
        return totalFee;
    }

    // Get all EVM wallets associated with this contract
    // This function uses the zrSIgn contract to get all wallets of the EVM type that belong to this contract
    function getEVMWallets() public view virtual returns (string[] memory) {
        return IZrSign(zrSign).getZrKeys(EVMWalletType, address(this));
    }

    // Get an EVM wallet associated with this contract by index
    // This function uses the zrSIgn contract to get a specific EVM wallet that belongs to this contract, specified by an index
    // Parameter:
    // - index: The index of the EVM wallet to be retrieved
    function getEVMWallet(uint256 index) public view returns (string memory) {
        return IZrSign(zrSign).getZrKey(EVMWalletType, address(this), index);
    }

    // Encode data using RLP
    // This function uses the RLPWriter library to encode data into RLP format
    function rlpEncodeData(bytes memory data)
        internal
        virtual
        returns (bytes memory)
    {
        return data.writeBytes();
    }

    // Encode a transaction using RLP
    // This function uses the RLPWriter library to encode a transaction into RLP format
    function rlpEncodeTransaction(
        uint256 nonce,
        uint256 gasPrice,
        uint256 gasLimit,
        address to,
        uint256 value,
        bytes memory data
    ) internal virtual returns (bytes memory) {
        bytes memory nb = nonce.writeUint();
        bytes memory gp = gasPrice.writeUint();
        bytes memory gl = gasLimit.writeUint();
        bytes memory t = to.writeAddress();
        bytes memory v = value.writeUint();
        return _encodeTransaction(nb, gp, gl, t, v, data);
    }

    // Helper function to encode a transaction
    // This function is used by the rlpEncodeTransaction function to encode a transaction into RLP format
    function _encodeTransaction(
        bytes memory nonce,
        bytes memory gasPrice,
        bytes memory gasLimit,
        bytes memory to,
        bytes memory value,
        bytes memory data
    ) internal pure returns (bytes memory) {
        bytes memory zb = uint256(0).writeUint();
        bytes[] memory payload = new bytes[](9);
        payload[0] = nonce;
        payload[1] = gasPrice;
        payload[2] = gasLimit;
        payload[3] = to;
        payload[4] = value;
        payload[5] = data;
        payload[6] = zb;
        payload[7] = zb;
        payload[8] = zb;
        return payload.writeList();
    }
}

contract ZrSignTransferETH is ZrSignConnect {
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    uint256 internal _gasPrice = 5000000000;
    uint256 internal _gasLimit = 250000;
    bytes32 internal constant sepoliaChainId =
        0xafa90c317deacd3d68f330a30f96e4fa7736e35e8d1426b2e1b2c04bce1c2fb7;
    uint256 internal _nonce = 0;

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(
        uint256 _fromKeyIndex,
        address _to,
        uint256 _value,
        bytes memory _data
    ) public {
        bytes memory data = rlpEncodeData(_data);
        bytes memory rlpTransactionData = rlpEncodeTransaction(
            _nonce,
            _gasPrice,
            _gasLimit,
            _to,
            _value,
            data
        );
        reqSignForTx(
            EVMWalletType,
            _fromKeyIndex,
            sepoliaChainId,
            rlpTransactionData,
            true
        );
        _nonce++;
    }

    function submitTransaction(
        uint256 fromKeyIndex,
        address to,
        uint256 value,
        uint256 gasPrice,
        uint256 gasLimit,
        uint256 nonce,
        bytes memory data
    ) public {
        bytes memory rlpPayloadData = rlpEncodeData(data);
        bytes memory rlpTransactionData = rlpEncodeTransaction(
            nonce,
            gasPrice,
            gasLimit,
            to,
            value,
            rlpPayloadData
        );
        reqSignForTx(
            EVMWalletType,
            fromKeyIndex,
            sepoliaChainId,
            rlpTransactionData,
            true
        );
    }

    function submitTransaction(
        uint256 fromKeyIndex,
        address to,
        uint256 value,
        uint256 gasPrice,
        uint256 gasLimit,
        uint256 nonce,
        bytes memory data,
        bool broadcast
    ) public {
        bytes memory rlpPayloadData = rlpEncodeData(data);
        bytes memory rlpTransactionData = rlpEncodeTransaction(
            nonce,
            gasPrice,
            gasLimit,
            to,
            value,
            rlpPayloadData
        );
        reqSignForTx(
            EVMWalletType,
            fromKeyIndex,
            sepoliaChainId,
            rlpTransactionData,
            broadcast
        );
    }
}