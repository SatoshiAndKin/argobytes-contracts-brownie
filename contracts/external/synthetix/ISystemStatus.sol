// SPDX-License-Identifier: You can't license an interface
pragma solidity 0.7.6;

interface ISystemStatus {
    function requireSystemActive() external view;

    function requireIssuanceActive() external view;

    function requireExchangeActive() external view;

    function requireSynthActive(bytes32 currencyKey) external view;

    function requireSynthsActive(
        bytes32 sourceCurrencyKey,
        bytes32 destinationCurrencyKey
    ) external view;
}
