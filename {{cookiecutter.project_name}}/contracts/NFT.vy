# @version >=0.3.4
# SPDX-License-Identifier: MIT

# import
from vyper.interfaces import ERC165
#from vyper.interfaces import ERC1155Receiver


# Mapping from token ID to account balances
_balances: public(HashMap[address, HashMap[uint256, uint256]])

# Mapping from account to operator approvals
_operatorApprovals: HashMap[address, HashMap[address, bool]]

# Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
_uri: String[256]

# The total number of possible tokens to be minted within the main NFT
# Set this number by the cookiecutter
BATCH_SIZE: constant(uint256) = 128

# callback number of bytes
CALLBACK_NUMBYTES: constant(uint256) = 1024

# URI length set to 300. 
MAX_URI_LENGTH: constant(uint256) = 256


# Events
event TransferSingle:
    # Emits on transfer of a single token
    _operator:   indexed(address)
    _fromAddress: indexed(address)
    _to: indexed(address)
    _id: uint256
    _values: uint256

event TransferBatch:
    # Emits on batch transfer of tokens. the ids array correspond with the values array by their position
    _operator: indexed(address) # indexed
    _fromAddress: indexed(address)
    _to: indexed(address)
    _ids: DynArray[uint256, BATCH_SIZE]
    _values: DynArray[uint256, BATCH_SIZE]


event ApprovalForAll:
    # MUST emit when approval for a second party/operator address to manage all tokens for an owner address is enabled or disabled (absence of an action assumes disabled).  
    _owner: indexed(address)
    _operator: indexed(address)
    _approved: bool


event URI:
    # Call when URI is modified
    _value: String[MAX_URI_LENGTH]
    _id: indexed(uint256)


# Interfaces

implements: ERC165

# ERC1155 Token Receiver

interface ERC1155TokenReceiver:
    def onERC1155Received(
        _operator: address,
        _from: address, 
        _id: uint256, 
        _value: uint256, 
        _data: Bytes[CALLBACK_NUMBYTES]
        ) -> bytes4: payable

    def onERC1155BatchReceived(
        _operator: address,
        _to: address,
        _ids: DynArray[uint256, BATCH_SIZE],
        _values: DynArray[uint256, BATCH_SIZE],
        _data: Bytes[CALLBACK_NUMBYTES]
    ) -> bytes4: payable


@external
def __init__():
    pass


@internal
def _setURI(uri_: String[MAX_URI_LENGTH]):
    self._uri = uri_

@internal
@view
def balanceOf(account: address, id: uint256) -> uint256:
    assert account != ZERO_ADDRESS, "ERC1155: address zero is not a valid owner"
    return self._balances[account][id]


@external
@view
def balanceOfBatch(_owners: DynArray[address, BATCH_SIZE], _ids: DynArray[uint256, BATCH_SIZE]) -> DynArray[uint256,BATCH_SIZE]:
    assert len(_owners) == len(_ids), "ERC1155: accounts and ids length mismatch"

    batchBalances: DynArray[uint256, BATCH_SIZE] = []
    
    for i in _ids:
        owner: address = _owners[i]
        id: uint256 = _ids[i]
        batchBalances.append(self.balanceOf(owner, id))

    return batchBalances

@external
def setApprovalForAll(operator: address, approved: bool):
    self._setApprovalForAll(msg.sender, operator, approved)

@view
@internal
def isApprovedForAll(account: address, operator: address) -> bool:
    return self._operatorApprovals[account][operator]


@external
def safeTransferFrom(_from: address, _to: address, _id: uint256, _value: uint256, _data: Bytes[CALLBACK_NUMBYTES]):
    """
    """
    assert _from == msg.sender or self.isApprovedForAll(_from, msg.sender), "ERC1155: caller is not token owner or approved"
    self._safeTransferFrom(_from, _to, _id, _value, _data)



@external
def safeBatchTransferFrom(_from: address, _to: address, _ids: DynArray[uint256, BATCH_SIZE], _values: DynArray[uint256, BATCH_SIZE], _data: Bytes[CALLBACK_NUMBYTES]):
    """
    """
    assert _from == msg.sender or self.isApprovedForAll(_from, msg.sender), "ERC1155: caller is not token owner or approved"
    self._safeBatchTransferFrom(_from, _to, _ids, _values, _data)



@internal
def _safeTransferFrom(_from: address, _to: address, _id: uint256, _value: uint256, _data: Bytes[1024]):
    assert _to != ZERO_ADDRESS, "ERC1155: transfer to the zero address"

    _operator: address = msg.sender
    # ids: uint256[1] = [id]
    # values: uint256[1] = [value]

    # self._beforeTokenTransfer(operator, from, to, ids, values, data)

    fromBalance: uint256 = self._balances[_from][_id]
    assert fromBalance >= _value, "ERC1155: insufficient balance for transfer"
    self._balances[_from][_id] = fromBalance - _value
    self._balances[_to][_id] += _value

    log TransferSingle(_operator, _from, _to, _id, _value)




@internal
def _safeBatchTransferFrom(_from: address, _to: address, _ids: DynArray[uint256, BATCH_SIZE], _values: DynArray[uint256, BATCH_SIZE], _data: Bytes[CALLBACK_NUMBYTES]):
    """
    @notice Transfers `_values` value(s) of `_ids` from the `_from` address to the `_to` address specified (with safety call).
    @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
    MUST revert if `_to` is the zero address.
    MUST revert if length of `_ids` is not the same as length of `_values`.
    MUST revert if any of the balance(s) of the holder(s) for token(s) in `_ids` is lower than the respective value(s) in `_values` sent to the recipient.
    MUST revert on any other error.        
    MUST emit `TransferSingle` or `TransferBatch` event(s) such that all the balance changes are reflected (see "Safe Transfer Rules" section of the standard).
    Balance changes and events MUST follow the ordering of the arrays (_ids[0]/_values[0] before _ids[1]/_values[1], etc).
    After the above conditions for the transfer(s) in the batch are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call the relevant `ERC1155TokenReceiver` hook(s) on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).                      
    @param _from    Source address
    @param _to      Target address
    @param _ids     IDs of each token type (order and length must match _values array)
    @param _values  Transfer values per token type (order and length must match _ids array)
    @param _data    Additional data with no specified format, MUST be sent unaltered in call to the `ERC1155TokenReceiver` hook(s) on `_to`
    """
    assert len(_ids) == len(_values), "ERC1155: ids and values length mismatch"
    assert _to != ZERO_ADDRESS, "ERC1155: transfer to the zero address"

    _operator: address = msg.sender

    # self._beforeTokenTransfer(operator, from, to, ids, values, data)

    for i in _ids:
        id: uint256 = _ids[i]
        value: uint256 = _values[i]

        fromBalance: uint256 = self._balances[_from][id]
        assert fromBalance >= value, "ERC1155: insufficient balance for transfer"
        self._balances[_from][id] = fromBalance - value
        self._balances[_to][id] += value

    log TransferBatch(_operator, _from, _to, _ids, _values)

    # self._afterTokenTransfer(operator, from, to, ids, values, data)


@internal
def _mint(_to: address, _id: uint256, _value: uint256, _data: Bytes[CALLBACK_NUMBYTES]): 
    assert _to != ZERO_ADDRESS, "ERC1155: mint to the zero address"

    _operator: address = msg.sender

    # self._beforeTokenTransfer(operator, ZERO_ADDRESS, to, id, values, data)

    self._balances[_to][_id] += _value
    log TransferSingle(_operator, ZERO_ADDRESS, _to, _id, _value)

    # self._afterTokenTransfer(operator, ZERO_ADDRESS, to, id, value, data)


@internal
def _mintBatch(_to: address, _ids: DynArray[uint256, BATCH_SIZE], _values: DynArray[uint256, BATCH_SIZE], _data: Bytes[CALLBACK_NUMBYTES]):
    assert _to != ZERO_ADDRESS, "ERC1155: mint to the zero address"
    assert len(_ids) == len(_values), "ERC1155: ids and values length mismatch"

    _operator: address = msg.sender

    # self._beforeTokenTransfer(operator, ZERO_ADDRESS, to, ids, values, data)

    for i in _ids:
        self._balances[_to][i] += _values[i]

    log TransferBatch(_operator, ZERO_ADDRESS, _to, _ids, _values)

@internal
def _burn(_from: address, _id: uint256, _value: uint256):
    assert _from != ZERO_ADDRESS, "ERC1155: burn from the zero address"

    _operator: address = msg.sender

    # self._beforeTokenTransfer(operator, from, ZERO_ADDRESS, id, values, b"")

    fromBalance: uint256 = self._balances[_from][_id]
    assert fromBalance >= _value, "ERC1155: burn value exceeds balance"
    self._balances[_from][_id] = fromBalance - _value

    log TransferSingle(_operator, _from, ZERO_ADDRESS, _id, _value)

    # self._afterTokenTransfer(operator, from, ZERO_ADDRESS, id, values, b"")

@internal
def _burnBatch(_from: address, _ids: DynArray[uint256, BATCH_SIZE], _values: DynArray[uint256, BATCH_SIZE]):
    assert _from != ZERO_ADDRESS, "ERC1155: burn from the zero address"
    assert len(_ids) == len(_values), "ERC1155: ids and values length mismatch"

    _operator: address = msg.sender

    # self._beforeTokenTransfer(operator, from, ZERO_ADDRESS, ids, values, b"")

    for i in _ids:
        id: uint256 = _ids[i]
        value: uint256 = _values[i]

        fromBalance: uint256 = self._balances[_from][id]
        assert fromBalance >= value, "ERC1155: burn value exceeds balance"
        self._balances[_from][_id] = fromBalance - value

    log TransferBatch(_operator, _from, ZERO_ADDRESS, _ids, _values)

    # self._afterTokenTransfer(operator, from, ZERO_ADDRESS, ids, values, b"")


@internal
def _setApprovalForAll(_owner: address, _operator: address, _approved: bool):
    assert _owner != _operator, "ERC1155: setting approval status for self"
    self._operatorApprovals[_owner][_operator] = _approved
    log ApprovalForAll(_owner, _operator, _approved)

# @internal
# def _beforeTokenTransfer(operator: address,from: address,to: address,ids: uint256[4],values: uint256[4],data: Bytes[CALLBACK_NUMBYTES]) -> None:
#     pass

# @internal
# def _afterTokenTransfer(operator: address, from: address, to: address, ids: uint256[4], values: uint256[4], data: Bytes[CALLBACK_NUMBYTES]) -> None:
#     pass


@pure
@external
def supportsInterface(interfaceId: bytes4) -> bool:
    """
    @dev Returns True if the interface is supported
    @param interfaceId bytes4 interface identifier
    """
    return interfaceId in [
        ERC165_INTERFACE_ID,
        ERC1155_INTERFACE_ID,
    ]

