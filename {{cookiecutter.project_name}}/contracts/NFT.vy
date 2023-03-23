# @version >=0.3.4
# SPDX-License-Identifier: MIT

from vyper.interfaces import ERC165
from vyper.interfaces import ERC115
from vyper.interfaces import IERC1155MetadataURI
from vyper.interfaces import IERC1155Receiver

# Mapping from token ID to account balances
_balances: public(HashMap[address, HashMap[uint256, uint256]])

# Mapping from token ID to account balances
_balances: public(HashMap[address, HashMap[uint256, uint256]])

# Mapping from account to operator approvals
_operatorApprovals: HashMap[address, HashMap[address, bool]]

# Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
_uri: String[100]

# The total number of possible tokens to be minted within the main NFT
# Set this number by the cookiecutter
BATCH_SIZE: constant(uint256) = 128

# callback number of bytes
CALLBACK_NUMBYTES: constant(uint256) = 1024

# URI length set to 300. 
MAX_URI_LENGTH: constant(uint256) = 256


# Events
"""
@dev Either `TransferSingle` or `TransferBatch` MUST emit when tokens are transferred, including zero value transfers as well as minting or burning (see "Safe Transfer Rules" section of the standard).      
"""
event TransferSingle:
    # Emits on transfer of a single token
    operator:   indexed(address)
    fromAddress: indexed(address)
    to: indexed(address)
    id: uint256
    value: uint256

event TransferBatch:
    # Emits on batch transfer of tokens. the ids array correspond with the values array by their position
    operator: indexed(address) # indexed
    fromAddress: indexed(address)
    to: indexed(address)
    ids: DynArray[uint256, BATCH_SIZE]
    values: DynArray[uint256, BATCH_SIZE]

"""
@dev MUST emit when approval for a second party/operator address to manage all tokens for an owner address is enabled or disabled (absence of an event assumes disabled).  
"""
event ApprovalForAll:
    owner: indexed(address)
    operator: indexed(address)
    approved: bool

"""
@dev MUST emit when the URI is updated for a token ID.
"""
event URI:
    # This emits when the URI gets changed
    value: String[MAX_URI_LENGTH]
    id: indexed(uint256)

# Interfaces

implements: ERC165

interface ERC1155Receiver:
    def onERC1155BatchReceived(
        operator: address,
        to: address, 
        ids: uint256, 
        amounts: uint256, 
        data: Bytes[CALLBACK_NUMBYTES]) -> bytes32: payable

    def _doSafeBatchTransferAcceptanceCheck(
        operator: address,
        to: address,
        ids: DynArray[uint256, BATCH_SIZE],
        amounts: DynArray[uint256, BATCH_SIZE],
        data: Bytes[CALLBACK_NUMBYTES]
    ) -> bytes32: payable

    if to.is_contract():
        try:
            response: bytes32 = ERC1155Receiver(to).onERC1155BatchReceived(operator, to, ids, amounts, data)
            if response != IERC1155Receiver.onERC1155BatchReceived.selector:
                revert("ERC1155: ERC1155Receiver rejected tokens")
        except:
            revert("ERC1155: transfer to non-ERC1155Receiver implementer")



@external
def __init__():
    """
    @dev Contract constructor.
    """
    
{%- if cookiecutter.mintable == 'y' %}
    self.owner = msg.sender
{%- endif %}

{%- if cookiecutter.updatable_uri == 'y' %}
    self._setURI = "{{cookiecutter.base_uri}}"
{%- endif %}


@internal
def _setURI(uri_: String[100]) -> None:
    self._uri = uri_

@internal
def balanceOf(account: address, id: uint256) -> (uint256, uint256):
    assert account != ZERO_ADDRESS, "ERC1155: address zero is not a valid owner"
    return self._balances[account][id]


@external
@view
def balanceOfBatch(accounts: DynArray[address, BATCH_SIZE], ids: DynArray[uint256, BATCH_SIZE]) -> DynArray[uint256,BATCH_SIZE]:
    assert len(accounts) == len(ids), "ERC1155: accounts and ids length mismatch"

    batchBalances: DynArray[uint256, BATCH_SIZE] = []

    for i in range(len(ids)):
        batchBalances = self.balanceOf(accounts[i], ids[i])

    return batchBalances

@external
def setApprovalForAll(operator: address, approved: bool) -> None:
    self._setApprovalForAll(msg.sender, operator, approved)

@view
@external
def isApprovedForAll(account: address, operator: address) -> bool:
    return self._operatorApprovals[account][operator]

"""
@param _from    Source address
@param _to      Target address
@param _ids     IDs of each token type (order and length must match _values array)
@param _values  Transfer amounts per token type (order and length must match _ids array)
@param _data    Additional data with no specified format, MUST be sent unaltered in call to the `ERC1155TokenReceiver` hook(s) on `_to`
    */
"""
@external
def safeTransferFrom(_from: address, _to: address, _id: uint256, _amount: uint256, _data: Bytes[CALLBACK_NUMBYTES]) -> None:
    assert _from == msg.sender or self.isApprovedForAll(_from, msg.sender), "ERC1155: caller is not token owner or approved"
    self._safeTransferFrom(_from, _to, id, amount, data)

@external
def safeBatchTransferFrom(from: address, to: address, ids: DynArray[uint256, BATCH_SIZE], amounts: DynArray[uint256, BATCH_SIZE], data: Bytes[CALLBACK_NUMBYTES]) -> None:
    assert from == msg.sender or self.isApprovedForAll(from, msg.sender), "ERC1155: caller is not token owner or approved"
    self._safeBatchTransferFrom(from, to, ids, amounts, data)

@internal
def _safeTransferFrom(from: address, to: address, id: uint256, amount: uint256, data: Bytes[1024]) -> None:
    assert to != ZERO_ADDRESS, "ERC1155: transfer to the zero address"

    operator: address = msg.sender
    # ids: uint256[1] = [id]
    # amounts: uint256[1] = [amount]

    # self._beforeTokenTransfer(operator, from, to, ids, amounts, data)

    fromBalance: uint256 = self._balances[from][id]
    assert fromBalance >= amount, "ERC1155: insufficient balance for transfer"
    self._balances[from][id] = fromBalance - amount
    self._balances[to][id] += amount

    log TransferSingle(operator, from, to, id, amount)

    # self._afterTokenTransfer(operator, from, to, ids, amounts, data)

    self._doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data)

@internal
def _safeBatchTransferFrom(from: address, to: address, ids: DynArray[uint256, BATCH_SIZE], amounts: DynArray[uint256, BATCH_SIZE], data: Bytes[CALLBACK_NUMBYTES]) -> None:
    assert len(ids) == len(amounts), "ERC1155: ids and amounts length mismatch"
    assert to != ZERO_ADDRESS, "ERC1155: transfer to the zero address"

    operator: address = msg.sender

    # self._beforeTokenTransfer(operator, from, to, ids, amounts, data)

    for i in range(len(ids)):
        id: uint256 = ids[i]
        amount: uint256 = amounts[i]

        fromBalance: uint256 = self._balances[from][id]
        assert fromBalance >= amount, "ERC1155: insufficient balance for transfer"
        self._balances[from][id] = fromBalance - amount
        self._balances[to][id] += amount

    log TransferBatch(operator, from, to, ids, amounts)

    # self._afterTokenTransfer(operator, from, to, ids, amounts, data)

    self._doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data)

@internal
def _setURI(newuri: String[MAX_URI_LENGTH]) -> None:
    self._uri = newuri

@internal
def _mint(to: address, id: uint256, amount: uint256, data: Bytes[CALLBACK_NUMBYTES]) -> None: 
    assert to != ZERO_ADDRESS, "ERC1155: mint to the zero address"

    operator: address = msg.sender

    # self._beforeTokenTransfer(operator, ZERO_ADDRESS, to, id, amounts, data)

    self._balances[to][id] += amount
    log TransferSingle(operator, ZERO_ADDRESS, to, id, amount)

    # self._afterTokenTransfer(operator, ZERO_ADDRESS, to, id, amount, data)

    self._doSafeTransferAcceptanceCheck(operator, ZERO_ADDRESS, to, id, amount, data)


@internal
def _mintBatch(to: address, ids: DynArray[uint256, BATCH_SIZE], amounts: DynArray[uint256, BATCH_SIZE], data: Bytes[CALLBACK_NUMBYTES]) -> None:
    assert to != ZERO_ADDRESS, "ERC1155: mint to the zero address"
    assert len(ids) == len(amounts), "ERC1155: ids and amounts length mismatch"

    operator: address = msg.sender

    # self._beforeTokenTransfer(operator, ZERO_ADDRESS, to, ids, amounts, data)

    for i in range(len(ids)):
        self._balances[to][id] += amounts[i]

    log TransferBatch(operator, ZERO_ADDRESS, to, ids, amounts)

    # self._afterTokenTransfer(operator, ZERO_ADDRESS, to, ids, amounts, data)

    self._doSafeBatchTransferAcceptanceCheck(operator, ZERO_ADDRESS, to, ids, amounts, data)

@internal
def _burn(from: address, id: uint256, amount: uint256) -> None:
    assert from != ZERO_ADDRESS, "ERC1155: burn from the zero address"

    operator: address = msg.sender

    # self._beforeTokenTransfer(operator, from, ZERO_ADDRESS, id, amounts, b"")

    fromBalance: uint256 = self._balances[from][id]
    assert fromBalance >= amount, "ERC1155: burn amount exceeds balance"
    self._balances[from][id] = fromBalance - amount

    log TransferSingle(operator, from, ZERO_ADDRESS, id, amount)

    # self._afterTokenTransfer(operator, from, ZERO_ADDRESS, id, amounts, b"")

@internal
def _burnBatch(from: address,ids: DynArray[uint256, BATCH_SIZE], amounts: DynArray[uint256, BATCH_SIZE]) -> None:
    assert from != ZERO_ADDRESS, "ERC1155: burn from the zero address"
    assert len(ids) == len(amounts), "ERC1155: ids and amounts length mismatch"

    operator: address = msg.sender

    # self._beforeTokenTransfer(operator, from, ZERO_ADDRESS, ids, amounts, b"")

    for i in range(len(ids)):
        id: uint256 = ids[i]
        amount: uint256 = amounts[i]

        fromBalance: uint256 = self._balances[from][id]
        assert fromBalance >= amount, "ERC1155: burn amount exceeds balance"
        self._balances[from][id] = fromBalance - amount

    log TransferBatch(operator, from, ZERO_ADDRESS, ids, amounts)

    # self._afterTokenTransfer(operator, from, ZERO_ADDRESS, ids, amounts, b"")

"""
@dev Approve `operator` to operate on all of `owner` tokens
"""

@internal
def _setApprovalForAll(owner: address, operator: address, approved: bool) -> None:
    assert owner != operator, "ERC1155: setting approval status for self"
    self._operatorApprovals[owner][operator] = approved
    log ApprovalForAll(owner, operator, approved)

# @internal
# def _beforeTokenTransfer(operator: address,from: address,to: address,ids: uint256[4],amounts: uint256[4],data: Bytes[CALLBACK_NUMBYTES]) -> None:
#     pass

# @internal
# def _afterTokenTransfer(operator: address, from: address, to: address, ids: uint256[4], amounts: uint256[4], data: Bytes[CALLBACK_NUMBYTES]) -> None:
#     pass

@private
def _doSafeTransferAcceptanceCheck(operator: address, from: address, to: address, id: uint256, amount: uint256, data: Bytes[CALLBACK_NUMBYTES]) -> None:
    if is_contract(to):
        try:
            response: bytes32 = IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data)
            if response != IERC1155Receiver.onERC1155Received.selector:
                raise("ERC1155: ERC1155Receiver rejected tokens")
        except Exception as e:
            raise e.message

@private
def _doSafeBatchTransferAcceptanceCheck(operator: address, from: address, to: address, ids: uint256[4], amounts: uint256[4], data: Bytes[CALLBACK_NUMBYTES]) -> None:
    if is_contract(to):
        try:
            response: bytes32 = IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data)
            if response != IERC1155Receiver.onERC1155BatchReceived.selector:
                raise("ERC1155: ERC1155Receiver rejected tokens")
        except Exception as e:
            raise e.message




@external
@view
def supportsInterface(interfaceID: bytes32) -> bool:
    return (
        interfaceID == 0x01ffc9a7 ||    # ERC-165 support (i.e. `bytes4(keccak256('supportsInterface(bytes4)'))`).
        interfaceID == 0x4e2312e0 ||    # ERC-1155 `ERC1155TokenReceiver` support
        interfaceID == 0x0e89341c       # The URI MUST point to a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema".
    )
