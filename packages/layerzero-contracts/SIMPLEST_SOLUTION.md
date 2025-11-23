# Simplest Cross-Chain Swap Implementation

## 🎯 Design Goal

Enable swaps where:
- LP's tokens start on **World Chain**
- Strategy lives on **Base Chain**  
- Trader swaps against strategy on Base
- **NO modifications to Aqua.sol** ✅

## 💡 The Simple Solution

### Core Idea: "Shadow LP Pattern"

```
World Chain                              Base Chain
═══════════                              ══════════

Real LP                                  Shadow LP (Proxy)
├─ Deposits to Vault                     ├─ Holds bridged tokens
├─ Controls strategy                     ├─ Ships strategy to Aqua
└─ Receives profits                      └─ Executes swaps

         │                                        │
         │ Tokens bridged once                   │
         ├────────────────────────►              │
                                                  ▼
                                           Aqua sees normal LP ✅
```

## 🔄 Complete Flow

### Step 1: LP Setup (One-Time)

```
World Chain                              Base Chain
───────────                              ──────────

1. LP deposits tokens to Vault
   vault.lockAndBridge(
     USDC: 2e6,
     USDT: 2e6,
     dstEid: Base,
     strategy: {...}
   )
        │
        ├─► Lock tokens in Vault ✅
        │
        │ Bridge tokens via LayerZero OFT
        ├────────────────────────►  2. Proxy receives tokens
        │                              USDC: 2e6 ✅
        │                              USDT: 2e6 ✅
        │                              ↓
        │                           3. Proxy approves Aqua
        │                              IERC20(USDC).approve(aqua)
        │                              IERC20(USDT).approve(aqua)
        │                              ↓
        │                           4. Proxy ships strategy
        │                              aqua.ship(
        │                                app,
        │                                strategy,
        │                                [USDC, USDT],
        │                                [2e6, 2e6]
        │                              )
        │                              ↓
        │                              Aqua tracks Proxy's balances ✅
        │                              Tokens stay in Proxy wallet ✅
        │
        │ Confirmation
   ◄────────────────────────────   5. Strategy active!
        │
   Vault tracks: LP owns this strategy
```

### Step 2: Trader Swaps

```
World Chain                              Base Chain
───────────                              ──────────

1. Trader: "Swap 1 USDC for USDT"
   trader.initiateSwap(
     strategy,
     amountIn: 1e6 USDC,
     minOut: 0.99e6
   )
        │
        ├─► Lock 1 USDC in SwapInitiator
        │
        │ Bridge USDC + Message
        ├────────────────────────►  2. Proxy receives:
        │                              - 1 USDC (bridged)
        │                              - Swap request
        │                              ↓
        │                           3. Proxy executes swap
        │                              AMM.swapExactIn(
        │                                strategy,
        │                                zeroForOne: true,
        │                                amountIn: 1e6,
        │                                minOut: 0.99e6,
        │                                to: address(this),
        │                                takerData: abi.encode(trader, srcEid)
        │                              )
        │                              ↓
        │                           4. Inside AMM.swapExactIn():
        │                              
        │                              aqua.pull(
        │                                Proxy,  // maker (Proxy acts as LP)
        │                                strategyHash,
        │                                USDT,
        │                                0.996e6,
        │                                address(Proxy) // to
        │                              )
        │                              ↓
        │                              // This does:
        │                              safeTransferFrom(
        │                                Proxy,      // from (has tokens!)
        │                                Proxy,      // to (receives output)
        │                                0.996e6
        │                              ) ✅
        │                              ↓
        │                              IStableswapCallback(Proxy)
        │                                .stableswapCallback(...)
        │                              ↓
        │                           5. In callback:
        │                              
        │                              IERC20(USDC).approve(aqua, 1e6)
        │                              aqua.push(
        │                                Proxy,      // maker
        │                                app,
        │                                strategyHash,
        │                                USDC,
        │                                1e6
        │                              )
        │                              ↓
        │                              // This does:
        │                              safeTransferFrom(
        │                                Proxy,      // from (has bridged USDC!)
        │                                Proxy,      // to (back to proxy)
        │                                1e6
        │                              ) ✅
        │                              ↓
        │                              Aqua updates balances:
        │                              Proxy's USDC: 2e6 → 3e6 ✅
        │                              Proxy's USDT: 2e6 → 1.004e6 ✅
        │                              ↓
        │                           6. Proxy bridges USDT back
        │                              Bridge 0.996 USDT to trader
        │                              ↓
   ◄────────────────────────────   7. USDT arrives
        │                              Send to trader ✅
        │
   Trader receives 0.996 USDT! 🎉
```

## 📦 Required Contracts

### 1. LPVault (World Chain) - Simple Version

```solidity
contract LPVault is OApp {
    // Track LP deposits
    mapping(address lp => mapping(bytes32 strategyId => LPPosition)) public positions;
    
    struct LPPosition {
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
        uint32 baseEid;
        bool active;
    }
    
    /**
     * @notice LP deposits tokens and bridges to Base
     */
    function lockAndBridge(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint32 dstEid,
        bytes calldata strategyParams,
        bytes calldata lzOptions
    ) external payable returns (bytes32 strategyId) {
        // 1. Transfer tokens from LP
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);
        
        // 2. Bridge tokens to Base Proxy
        // (Using LayerZero OFT or similar)
        _bridgeTokens(token0, amount0, dstEid);
        _bridgeTokens(token1, amount1, dstEid);
        
        // 3. Send message to Proxy to ship strategy
        bytes memory message = abi.encode(
            msg.sender, // real LP
            strategyParams,
            token0,
            token1,
            amount0,
            amount1
        );
        _lzSend(dstEid, message, lzOptions, MessagingFee(msg.value, 0), payable(msg.sender));
        
        // 4. Track position
        strategyId = keccak256(abi.encodePacked(msg.sender, strategyParams));
        positions[msg.sender][strategyId] = LPPosition({
            token0: token0,
            token1: token1,
            amount0: amount0,
            amount1: amount1,
            baseEid: dstEid,
            active: true
        });
    }
    
    /**
     * @notice LP withdraws (after docking strategy on Base)
     */
    function withdraw(bytes32 strategyId) external {
        LPPosition storage pos = positions[msg.sender][strategyId];
        require(pos.active, "Not active");
        
        // 1. Request proxy to dock strategy and bridge tokens back
        // 2. Wait for tokens to arrive
        // 3. Transfer to LP
        
        // For MVP: Manual process
        revert("Use dock() first on Base, then claim here");
    }
}
```

### 2. CrossChainSwapProxy (Base Chain) - The Key Contract

```solidity
contract CrossChainSwapProxy is OApp, IStableswapCallback {
    using SafeERC20 for IERC20;
    
    IAqua public immutable AQUA;
    IStableswapAMM public immutable AMM;
    
    // Track which strategies this proxy manages
    mapping(bytes32 strategyHash => StrategyInfo) public strategies;
    
    struct StrategyInfo {
        address realLP;      // LP's address on World
        uint32 srcEid;       // World chain ID
        bool active;
    }
    
    constructor(address _endpoint, address _delegate, address _aqua, address _amm) 
        OApp(_endpoint, _delegate) 
    {
        AQUA = IAqua(_aqua);
        AMM = IStableswapAMM(_amm);
    }
    
    /**
     * @notice Receive message from World: tokens arrived, ship strategy
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address,
        bytes calldata
    ) internal override {
        (
            address realLP,
            bytes memory strategyParams,
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        ) = abi.decode(_message, (address, bytes, address, address, uint256, uint256));
        
        // At this point, tokens should have arrived via bridge
        // (In practice, coordinate with OFT composer)
        
        // Approve Aqua to spend our tokens
        IERC20(token0).approve(address(AQUA), type(uint256).max);
        IERC20(token1).approve(address(AQUA), type(uint256).max);
        
        // Ship strategy with THIS contract as maker
        address[] memory tokens = new address[](2);
        tokens[0] = token0;
        tokens[1] = token1;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;
        
        bytes32 strategyHash = AQUA.ship(
            address(AMM),
            strategyParams,
            tokens,
            amounts
        );
        
        // Track strategy
        strategies[strategyHash] = StrategyInfo({
            realLP: realLP,
            srcEid: _origin.srcEid,
            active: true
        });
    }
    
    /**
     * @notice Execute swap - called after trader's tokens arrive
     */
    function executeSwap(
        IStableswapAMM.Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountIn,
        uint256 minAmountOut,
        address traderOnWorld,
        uint32 worldEid
    ) external returns (uint256 amountOut) {
        // Trader's tokenIn should already be in this contract (bridged)
        
        // Execute swap on AMM
        amountOut = AMM.swapExactIn(
            strategy,
            zeroForOne,
            amountIn,
            minAmountOut,
            address(this), // Receive output here
            abi.encode(traderOnWorld, worldEid) // Pass trader info
        );
        
        // After swap completes, bridge output token back to trader
        address tokenOut = zeroForOne ? strategy.token1 : strategy.token0;
        _bridgeToTrader(tokenOut, amountOut, traderOnWorld, worldEid);
    }
    
    /**
     * @notice Callback from AMM during swap
     */
    function stableswapCallback(
        address tokenIn,
        address, // tokenOut
        uint256 amountIn,
        uint256, // amountOut
        address maker,
        address app,
        bytes32 strategyHash,
        bytes calldata // takerData
    ) external override {
        require(msg.sender == address(AMM), "Only AMM");
        require(maker == address(this), "Maker must be this proxy");
        
        // Push trader's bridged tokenIn to Aqua
        IERC20(tokenIn).approve(address(AQUA), amountIn);
        AQUA.push(maker, app, strategyHash, tokenIn, amountIn);
    }
    
    function _bridgeToTrader(
        address token,
        uint256 amount,
        address trader,
        uint32 dstEid
    ) internal {
        // Bridge token back to World chain
        // Implementation depends on bridge (LayerZero OFT, etc.)
    }
}
```

## ✅ Why This Works

### 1. **No Aqua Modifications**
Aqua sees Proxy as a normal LP:
- Proxy has tokens in its wallet ✅
- Proxy ships strategy ✅
- Aqua calls `safeTransferFrom(Proxy, ...)` ✅

### 2. **Safe Token Flow**
```
LP deposits → Vault locks → Bridge to Proxy → Proxy holds
                                              ↓
                                     Aqua pull/push work ✅
```

### 3. **Standard AMM Callback**
Proxy implements `IStableswapCallback` just like any trader:
```solidity
function stableswapCallback(...) {
    // Approve and push - standard pattern
    IERC20(tokenIn).approve(aqua, amountIn);
    AQUA.push(maker, app, strategyHash, tokenIn, amountIn);
}
```

### 4. **LP Maintains Ownership**
- Vault tracks which strategies belong to which LP
- LP can trigger dock() and withdraw
- LP receives trading profits

## 🎯 Simplified MVP Flow

For fastest implementation:

1. **Manual bridging** (use LayerZero UI first)
2. **Deploy Proxy on Base**
3. **Proxy.ship() manually**
4. **Test single swap**
5. **Then automate with Vault**

This proves the concept without complex bridging logic!

## 🚀 Next Steps

Want me to:
1. ✅ Implement the CrossChainSwapProxy contract properly?
2. ✅ Add the bridging coordination logic?
3. ✅ Create deployment & test scripts?

The core insight: **Proxy on Base acts as LP, holds bridged tokens, Aqua works normally!**

