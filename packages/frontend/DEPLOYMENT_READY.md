# 🚀 Deployment Ready - Aqua0 Frontend

## ✅ Configuración Completa

### 1. Contratos Deployados

**Base Chain:**
- `StableswapAMM`: `0xeb99024504f5e73Fc857E4B2a0CF076C7F91fa2E`
- `ConcentratedLiquidity`: `0xDf12aaAdBaEc2C9cf9E56Bd4B807008530269839`

**WorldChain:**
- `Composer`: `0xc689cA9BC4C0176b8a0d50d4733A44Af83834Ae8`

**LayerZero:**
- `EID`: `30184`

### 2. Configuración de Variables de Entorno

Archivo `.env` creado con:
```bash
VITE_EID=30184
VITE_STABLESWAP_BASE=0xeb99024504f5e73Fc857E4B2a0CF076C7F91fa2E
VITE_CONCENTRATED_BASE=0xDf12aaAdBaEc2C9cf9E56Bd4B807008530269839
VITE_COMPOSER_WORLD=0xc689cA9BC4C0176b8a0d50d4733A44Af83834Ae8
VITE_WORLD_APP_ID=app_95353fdbbdc556589a013271729e7378
```

### 3. Arquitectura Cross-Chain

```
WorldChain (Source)          Base (Destination)
     │                              │
     ├─ User Auth (WorldID)         │
     ├─ Composer Contract           │
     ├─ Token Balances              │
     │         │                    │
     │         └──── LayerZero ────>├─ StableswapAMM
     │               (EID 30184)    ├─ ConcentratedLiquidity
     │                              │
     └── Transaction Hash ──────────┘
              (LayerZero Scan)
```

## 🔄 Flujo de Creación de Estrategia

### User Flow:
1. **Login con WorldID** → Verifica humanidad
2. **Selecciona tipo de estrategia**:
   - Stableswap (para stable pairs)
   - Concentrated Liquidity (para pares volátiles)
3. **Configura parámetros**:
   - Fee: 0-1.5% (convertido a basis points)
   - Token Pair: USDC/USDT (intercambiable)
4. **Submit → MiniKit Transaction**
5. **Loading (espera confirmación)**
6. **Success Screen**:
   - Transaction Hash
   - Link a LayerZero Scan

### Technical Flow:
```typescript
// 1. Usuario configura estrategia
{
  type: "stableswap",
  fee: 0.30,  // → 30 basis points
  tokenPair: { from: "USDC", to: "USDT" }
}

// 2. shipStrategyToChain crea la estructura
{
  maker: "0x...",  // Usuario autenticado
  token0: "0x79A02482A880bCE3F13e09Da970dC34db4CD24d1",
  token1: "0x79A02482A880bCE3F13e09Da970dC34db4CD24d1",
  feeBps: 30,
  amplificationFactor: 100,  // Para stableswap
  salt: "0xrandom..."
}

// 3. MiniKit envía transacción a WorldChain
MiniKit.commandsAsync.sendTransaction({
  transaction: [{
    address: COMPOSER_WORLD,
    abi: [...],
    functionName: "swapExactIn",
    args: [strategy, ...]
  }]
})

// 4. Composer en WorldChain → LayerZero → Base
// 5. Estrategia creada en Base
// 6. Transaction hash retornado
```

## ⚠️ Pendiente

### 1. Maker Address
Actualmente hardcodeado en `shipStrategy.ts` línea 37:
```typescript
const maker = '0x...' // TODO: Get from WorldID auth
```

**Opciones para obtenerla:**
- `MiniKit.walletAuth()`
- Guardar durante login con WorldID
- localStorage después de autenticación

### 2. Verificar Token Addresses
Las siguientes addresses de tokens en WorldChain necesitan verificación:
```typescript
VITE_USDC_WORLD=0x79A02482A880bCE3F13e09Da970dC34db4CD24d1
VITE_USDT_WORLD=0x79A02482A880bCE3F13e09Da970dC34db4CD24d1  // ← Mismo que USDC?
VITE_WETH_WORLD=0x4200000000000000000000000000000000000006
```

## 📝 Archivos Importantes

1. **`src/lib/shipStrategy.ts`** - Lógica de envío de estrategia
2. **`src/components/market-makers-tab.tsx`** - UI de creación
3. **`src/components/MiniKitProvider.tsx`** - Wrapper de MiniKit
4. **`.env`** - Variables de entorno
5. **`STRATEGY_INTEGRATION.md`** - Documentación técnica

## 🧪 Testing

Para testear la integración completa:

1. **Asegúrate de tener ngrok corriendo**:
   ```bash
   ngrok http 8080
   ```

2. **Actualiza vite.config.ts** con el dominio de ngrok en `allowedHosts`

3. **Abre en WorldApp** (mobile) el link de ngrok

4. **Flujo de prueba**:
   - Login con WorldID
   - Create Strategy → Stableswap
   - Fee: 0.30
   - Tokens: USDC → USDT
   - Submit
   - Verifica la transacción en LayerZero Scan

## 🔗 Links Útiles

- **LayerZero Scan**: https://layerzeroscan.com/tx/{txHash}
- **WorldID Docs**: https://docs.world.org/mini-apps
- **MiniKit Docs**: https://docs.world.org/mini-apps/commands/send-transaction
- **Aqua Protocol**: (pending)

## 📊 Contract Addresses Reference

### Base (Chain ID: 8453)
| Contract | Address |
|----------|---------|
| StableswapAMM | `0xeb99024504f5e73Fc857E4B2a0CF076C7F91fa2E` |
| ConcentratedLiquidity | `0xDf12aaAdBaEc2C9cf9E56Bd4B807008530269839` |

### WorldChain (Chain ID: 480)
| Contract | Address |
|----------|---------|
| Composer | `0xc689cA9BC4C0176b8a0d50d4733A44Af83834Ae8` |
| USDC | `0x79A02482A880bCE3F13e09Da970dC34db4CD24d1` |
| USDT | `0x79A02482A880bCE3F13e09Da970dC34db4CD24d1` ⚠️ |
| WETH | `0x4200000000000000000000000000000000000006` |
