import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy


# we skip coverage because this can end up being a LOT of calls which crashes ganche-cli
# parts 2: OneSplitOffchainAction.getAmounts -  avg: 945866  low: 23638  high: 1868095
# parts 3: OneSplitOffchainAction.getAmounts -  avg: 1105818  low: 23638  high: 2187998
# parts 10: was like 8 mil lol
def test_get_amounts(dai_erc20, no_call_coverage, onesplit_offchain_action, usdc_erc20, weth9_erc20, skip_coverage):
    eth_amount = 1e18
    dai_amount = 1e20
    # TODO: increasing parts will be fragile. some exchanges use a LOT of gas
    parts = 1
    zero_address = "0x0000000000000000000000000000000000000000"

    # getAmounts(address token_a, uint token_a_amount, address token_b, uint256 parts)
    tx = onesplit_offchain_action.getAmounts.transact(zero_address, eth_amount, dai_erc20, parts)

    print("tx 1 gas", tx.gas_used)

    # TODO: use amounts from the previous call
    tx = onesplit_offchain_action.getAmounts.transact(dai_erc20, dai_amount, zero_address, parts)

    print("tx 2 gas", tx.gas_used)

    # TODO: what should we assert?


# we skip coverage because this can end up being a LOT of calls which crashes ganche-cli
def test_action(onesplit, onesplit_offchain_action, dai_erc20, weth9_erc20):
    value = 1e17

    # make sure balances start zeroed
    assert onesplit_offchain_action.balance() == 0
    assert dai_erc20.balanceOf.call(onesplit_offchain_action) == 0
    assert weth9_erc20.balanceOf.call(onesplit_offchain_action) == 0

    # send some ETH into the action
    accounts[0].transfer(onesplit_offchain_action, value)

    # make sure balances match what we expect
    assert onesplit_offchain_action.balance() == value

    parts = 1
    zero_address = "0x0000000000000000000000000000000000000000"

    # trade ETH to WETH
    # this used to be USDC, but it has a weird proxy pattern

    # calculation distributions on-chain is expensive, so we do it here instead
    # function encodeExtraData(address src_token, address dest_token, uint src_amount, uint dest_min_tokens, uint256 parts)
    (expected_return_eth_to_token, extra_data_eth_to_token) = onesplit_offchain_action.encodeExtraData(
        zero_address, weth9_erc20, value, 1, parts)

    # tradeEtherToToken(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
    _eth_to_token_tx = onesplit_offchain_action.tradeEtherToToken(
        onesplit_offchain_action, weth9_erc20, 1, 0, extra_data_eth_to_token)

    # TODO: make sure ETH balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure USDC balance is non-zero

    # import pdb
    # pdb.set_trace()

    print("expected_return_eth_to_token: ", expected_return_eth_to_token)
    assert expected_return_eth_to_token > 0

    weth9_balance = weth9_erc20.balanceOf.call(onesplit_offchain_action)

    # TODO: we have an off by 1 issue here! how are we getting an extra weth9!
    # TODO: check that eth balance decreased as expected?
    assert weth9_balance >= expected_return_eth_to_token

    # trade WETH to DAI
    # function encodeExtraData(address src_token, address dest_token, uint src_amount, uint dest_min_tokens, uint256 parts)
    # TODO: proper src_amount based on the previous transaction
    (expected_return_token_to_token, extra_data_token_to_token) = onesplit_offchain_action.encodeExtraData(
        weth9_erc20, dai_erc20, weth9_balance, 1, parts)

    # tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
    onesplit_offchain_action.tradeTokenToToken(
        onesplit_offchain_action, weth9_erc20, dai_erc20, 1, 0, extra_data_token_to_token)

    dai_balance = dai_erc20.balanceOf.call(onesplit_offchain_action)

    assert dai_balance >= expected_return_token_to_token

    # TODO: make sure USDC balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure DAI balance is non-zero

    # trade DAI to ETH
    # function encodeExtraData(address src_token, address dest_token, uint src_amount, uint dest_min_tokens, uint256 parts)
    # TODO: proper src_amount based on the previous transaction
    (expected_return_token_to_eth, extra_data_token_to_eth) = onesplit_offchain_action.encodeExtraData(
        dai_erc20, zero_address, dai_balance, 1, parts)

    # tradeTokenToEther(address to, address src_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
    onesplit_offchain_action.tradeTokenToEther(onesplit_offchain_action, dai_erc20, 1, 0, extra_data_token_to_eth)

    eth_balance = onesplit_offchain_action.balance()

    # TODO: this should be equal, but we are getting an extra wei somehow
    assert eth_balance >= expected_return_token_to_eth

    # TODO: make sure DAI balance is zero (i think it will be swept back to accounts[0])
    # TODO: make sure ETH balance is non-zero
