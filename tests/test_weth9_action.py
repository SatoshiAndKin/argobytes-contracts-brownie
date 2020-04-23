import pytest
from brownie import accounts
from brownie.test import given, strategy
from hypothesis import settings


# @given(
#     value=strategy('uint256', max_value=1e18, min_value=1),
# )
def test_wrapping_and_unwrapping(weth9_erc20, weth9_action):
    value = 1e10

    # check starting balances
    assert weth9_action.balance() == 0
    assert weth9_erc20.balanceOf(weth9_action) == 0
    assert weth9_erc20.balanceOf(accounts[0]) == 0

    starting_eth = accounts[0].balance()

    # put some ETH into the action
    accounts[0].transfer(weth9_action, value)

    assert weth9_action.balance() == value
    assert weth9_erc20.balanceOf(accounts[0]) == 0
    assert weth9_erc20.balanceOf(weth9_action) == 0

    # do the wrapping
    weth9_action.wrap_all_to(accounts[0])

    # check balances after wrapping
    assert weth9_action.balance() == 0
    assert weth9_erc20.balanceOf(accounts[0]) == value
    assert weth9_erc20.balanceOf(weth9_action) == 0

    # put some WETH into the action
    assert weth9_erc20.transfer(weth9_action, value, {"from": accounts[0]})

    # do the unwrapping
    weth9_action.unwrap_all_to(accounts[0])

    # check ending balances
    assert accounts[0].balance() == starting_eth
    assert weth9_action.balance() == 0
    assert weth9_erc20.balanceOf(accounts[0]) == 0
    assert weth9_erc20.balanceOf(weth9_action) == 0
