pragma solidity 0.4.25;


/**
 * @title Synthetix Depot interface
 */
contract IDepot {
    function exchangeEtherForSynths() public payable returns (uint);

    function exchangeEtherForSynthsAtRate(uint guaranteedRate) external payable returns (uint);

    function depositSynths(uint amount) external;

    function withdrawMyDepositedSynths() external;

    // Deprecated ABI for MAINNET. Only used on Testnets
    function exchangeEtherForSNX() external payable returns (uint);

    function exchangeEtherForSNXAtRate(uint guaranteedRate) external payable returns (uint);

    function exchangeSynthsForSNX() external payable returns (uint);

    event MaxEthPurchaseUpdated(uint amount);
    event FundsWalletUpdated(address newFundsWallet);
    event Exchange(string fromCurrency, uint fromAmount, string toCurrency, uint toAmount);
    event SynthWithdrawal(address user, uint amount);
    event SynthDeposit(address indexed user, uint amount, uint indexed depositIndex);
    event SynthDepositRemoved(address indexed user, uint amount, uint indexed depositIndex);
    event SynthDepositNotAccepted(address user, uint amount, uint minimum);
    event MinimumDepositAmountUpdated(uint amount);
    event NonPayableContract(address indexed receiver, uint amount);
    event ClearedDeposit(
        address indexed fromAddress,
        address indexed toAddress,
        uint fromETHAmount,
        uint toAmount,
        uint indexed depositIndex
    );
}