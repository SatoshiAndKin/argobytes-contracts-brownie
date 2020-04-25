import brownie
import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings


# @given(
#     value=strategy('uint256', max_value=1e18, min_value=1e8),
# )
def test_uniswap_arbitrage(atomic_trade, dai_erc20, owned_vault, example_action, uniswap_action, usdc_erc20):
    assert owned_vault.balance() == 0
    assert example_action.balance() == 0

    value = 1e10

    # we use the zero address for ETH
    zero_address = "0x0000000000000000000000000000000000000000"

    # send some ETH into the vault
    accounts[0].transfer(owned_vault, value)
    # send some ETH into the sweep contract to simulate arbitrage profits
    accounts[0].transfer(example_action, value)

    # mint some gas token
    # TODO: how much should we make?
    owned_vault.mintGasToken()

    # make sure balances match what we expect
    assert owned_vault.balance() == value
    assert example_action.balance() == value

    # sweep a bunch of times to use up gas
    encoded_actions = atomic_trade.encodeActions(
        [
            uniswap_action,
            uniswap_action,
            uniswap_action,
            example_action,
        ],
        [
            # trade ETH to USDC
            # uniswap_action.tradeEtherToToken(address to, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
            uniswap_action.tradeEtherToToken.encode_input(uniswap_action, usdc_erc20, 1, 0, ""),
            # trade USDC to DAI
            # uniswap_action.tradeTokenToToken(address to, address src_token, address dest_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
            uniswap_action.tradeTokenToToken.encode_input(uniswap_action, usdc_erc20, dai_erc20, 1, 0, ""),
            # trade DAI to ETH
            # uniswap_action.tradeTokenToEther(address to, address src_token, uint dest_min_tokens, uint dest_max_tokens, bytes calldata extra_data)
            uniswap_action.tradeTokenToEther.encode_input(example_action, dai_erc20, 1, 0, ""),
            # add some faked profits
            example_action.sweep.encode_input(zero_address),
        ],
    )

    arbitrage_tx = owned_vault.atomicArbitrage([zero_address], value, encoded_actions, {'from': accounts[1]})

    # make sure balances match what we expect
    # TODO: what actual amounts should we expect? it's going to be variable since we forked mainnet
    assert arbitrage_tx.return_value > 0
    assert owned_vault.balance() > 0

    # TODO: should we compare this to running without burning gas token?
    print("gas_used_with_gastoken: ", arbitrage_tx.gas_used)