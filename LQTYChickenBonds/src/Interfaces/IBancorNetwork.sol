pragma solidity ^0.8.10;


/**
 * @dev Bancor Network interface
 */
interface IBancorNetwork {
    /**
     * @dev returns the set of all valid pool collections
     */
    function poolCollections() external view returns (address[] memory);

    /**
     * @dev returns the set of all liquidity pools
     */
    function liquidityPools() external view returns (address[] memory);

    /**
     * @dev returns the respective pool collection for the provided pool
     */
    function collectionByPool(address pool) external view returns (address);

    /**
     * @dev creates new pools
     *
     * requirements:
     *
     * - none of the pools already exists
     */
    function createPools(address[] calldata tokens, address poolCollection) external;

    /**
     * @dev migrates a list of pools between pool collections
     *
     * notes:
     *
     * - invalid or incompatible pools will be skipped gracefully
     */
    function migratePools(address[] calldata pools, address newPoolCollection) external;

    /**
     * @dev deposits liquidity for the specified provider and returns the respective pool token amount
     *
     * requirements:
     *
     * - the caller must have approved the network to transfer the tokens on its behalf (except for in the
     *   native token case)
     */
    function depositFor(
        address provider,
        address pool,
        uint256 tokenAmount
    ) external payable returns (uint256);

    /**
     * @dev deposits liquidity for the current provider and returns the respective pool token amount
     *
     * requirements:
     *
     * - the caller must have approved the network to transfer the tokens on its behalf (except for in the
     *   native token case)
     */
    function deposit(address pool, uint256 tokenAmount) external payable returns (uint256);

    /**
     * @dev deposits liquidity for the specified provider by providing an EIP712 typed signature for an EIP2612 permit
     * request and returns the respective pool token amount
     *
     * requirements:
     *
     * - the caller must have provided a valid and unused EIP712 typed signature
     */
    function depositForPermitted(
        address provider,
        address pool,
        uint256 tokenAmount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /**
     * @dev deposits liquidity by providing an EIP712 typed signature for an EIP2612 permit request and returns the
     * respective pool token amount
     *
     * requirements:
     *
     * - the caller must have provided a valid and unused EIP712 typed signature
     */
    function depositPermitted(
        address pool,
        uint256 tokenAmount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /**
     * @dev initiates liquidity withdrawal
     *
     * requirements:
     *
     * - the caller must have approved the contract to transfer the pool token amount on its behalf
     */
    function initWithdrawal(address poolToken, uint256 poolTokenAmount) external returns (uint256);

    /**
     * @dev initiates liquidity withdrawal by providing an EIP712 typed signature for an EIP2612 permit request
     *
     * requirements:
     *
     * - the caller must have provided a valid and unused EIP712 typed signature
     */
    function initWithdrawalPermitted(
        address poolToken,
        uint256 poolTokenAmount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /**
     * @dev cancels a withdrawal request, and returns the number of pool token amount associated with the withdrawal
     * request
     *
     * requirements:
     *
     * - the caller must have already initiated a withdrawal and received the specified id
     */
    function cancelWithdrawal(uint256 id) external returns (uint256);

    /**
     * @dev withdraws liquidity and returns the withdrawn amount
     *
     * requirements:
     *
     * - the provider must have already initiated a withdrawal and received the specified id
     * - the specified withdrawal request is eligible for completion
     * - the provider must have approved the network to transfer vBNT amount on its behalf, when withdrawing BNT
     * liquidity
     */
    function withdraw(uint256 id) external returns (uint256);

    /**
     * @dev performs a trade by providing the input source amount, and returns the trade target amount
     *
     * requirements:
     *
     * - the caller must have approved the network to transfer the source tokens on its behalf (except for in the
     *   native token case)
     */
    function tradeBySourceAmount(
        address sourceaddress,
        address targetaddress,
        uint256 sourceAmount,
        uint256 minReturnAmount,
        uint256 deadline,
        address beneficiary
    ) external payable returns (uint256);

    /**
     * @dev performs a trade by providing the input source amount and providing an EIP712 typed signature for an
     * EIP2612 permit request, and returns the trade target amount
     *
     * requirements:
     *
     * - the caller must have provided a valid and unused EIP712 typed signature
     */
    function tradeBySourceAmountPermitted(
        address sourceaddress,
        address targetaddress,
        uint256 sourceAmount,
        uint256 minReturnAmount,
        uint256 deadline,
        address beneficiary,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /**
     * @dev performs a trade by providing the output target amount, and returns the trade source amount
     *
     * requirements:
     *
     * - the caller must have approved the network to transfer the source tokens on its behalf (except for in the
     *   native token case)
     */
    function tradeByTargetAmount(
        address sourceaddress,
        address targetaddress,
        uint256 targetAmount,
        uint256 maxSourceAmount,
        uint256 deadline,
        address beneficiary
    ) external payable returns (uint256);

    /**
     * @dev performs a trade by providing the output target amount and providing an EIP712 typed signature for an
     * EIP2612 permit request and returns the target amount and fee, and returns the trade source amount
     *
     * requirements:
     *
     * - the caller must have provided a valid and unused EIP712 typed signature
     */
    function tradeByTargetAmountPermitted(
        address sourceaddress,
        address targetaddress,
        uint256 targetAmount,
        uint256 maxSourceAmount,
        uint256 deadline,
        address beneficiary,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /**
     * @dev deposits liquidity during a migration
     */
    function migrateLiquidity(
        address token,
        address provider,
        uint256 amount,
        uint256 availableAmount,
        uint256 originalAmount
    ) external payable;

    /**
     * @dev withdraws pending network fees, and returns the amount of fees withdrawn
     *
     * requirements:
     *
     * - the caller must have the ROLE_NETWORK_FEE_MANAGER privilege
     */
    function withdrawNetworkFees(address recipient) external returns (uint256);
}
