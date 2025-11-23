# Strategy Integration - TODO

## ✅ Implementado

1. **UI Components**
   - ✅ Formulario de creación de estrategia
   - ✅ Selector de tipo (Stableswap / Concentrated Liquidity)
   - ✅ Campos de Fee y Token Pair
   - ✅ Pantalla de loading
   - ✅ Pantalla de éxito con link a LayerZero Scan

2. **Integration Layer**
   - ✅ Archivo `src/lib/shipStrategy.ts` creado
   - ✅ Función `shipStrategyToChain` que usa MiniKit.commandsAsync.sendTransaction
   - ✅ Conversión de fee de porcentaje a basis points
   - ✅ Manejo de errores
   - ✅ Estructuras de Strategy correctas para ambos tipos (Stableswap y ConcentratedLiquidity)
   - ✅ ABIs completos basados en los contratos

## ⚠️ Pendiente - Configuración Requerida

### 1. Contract Addresses ✅ CONFIGURADO

Ya están configuradas en `.env`:

```bash
# LayerZero Endpoint ID
VITE_EID=30184

# Contract Addresses on Base
VITE_STABLESWAP_BASE=0xeb99024504f5e73Fc857E4B2a0CF076C7F91fa2E
VITE_CONCENTRATED_BASE=0xDf12aaAdBaEc2C9cf9E56Bd4B807008530269839

# Composer on World Chain
VITE_COMPOSER_WORLD=0xc689cA9BC4C0176b8a0d50d4733A44Af83834Ae8

# Token Addresses on WorldChain (TODO: verificar estas addresses)
VITE_USDC_WORLD=0x79A02482A880bCE3F13e09Da970dC34db4CD24d1
VITE_USDT_WORLD=0x79A02482A880bCE3F13e09Da970dC34db4CD24d1
VITE_WETH_WORLD=0x4200000000000000000000000000000000000006

# World ID App ID
VITE_WORLD_APP_ID=app_95353fdbbdc556589a013271729e7378
```

**NOTA**: Verifica que las addresses de tokens (USDC, USDT, WETH) sean correctas para WorldChain.

### 2. Maker Address
Actualizar en `src/lib/shipStrategy.ts` (línea 34):

Obtener la wallet address del usuario autenticado con WorldID:

```typescript
// TODO: Get the actual maker address from WorldID auth
const maker = '0x...' // This should come from the authenticated user
```

Opciones:
- Usar `MiniKit.walletAuth()` para obtener la address
- Guardar la address durante el login con WorldID
- Obtenerla del localStorage después de la autenticación

### 3. Chain Configuration
Asegurarse de que MiniKit esté configurado para WorldChain.

## 🔄 Flujo Completo

1. Usuario selecciona tipo de estrategia (Stableswap / Concentrated Liquidity)
2. Usuario ingresa:
   - Fee (0-1.5%)
   - Token pair (USDC/USDT default, con opción de intercambiar)
3. Click en "Create Strategy"
4. Se convierte fee a basis points (0.30% → 30 bps)
5. Se obtienen las addresses de los tokens
6. Se llama `shipStrategyToChain` vía MiniKit
7. Se muestra pantalla de loading mientras se procesa
8. Al completar:
   - Se obtiene el transaction hash
   - Se muestra pantalla de éxito
   - Link a `https://layerzeroscan.com/tx/{hash}`
9. Usuario puede volver a la lista de estrategias

## 📝 Notas

- El fee se ingresa como porcentaje (ej: 0.30) y se convierte a basis points (30)
- Los tokens actualmente disponibles son USDC y USDT (hardcoded)
- El link de LayerZero Scan usa: `https://layerzeroscan.com/tx/{txHash}`
- Se maneja el error mostrándolo en el campo de fee

## 🧪 Testing

Para testear sin deployar contratos, puedes temporalmente:
1. Comentar la llamada real a `shipStrategyToChain`
2. Descomentar el código de simulación (mock) en `handleSubmit`
3. Esto generará un hash ficticio y mostrará la UI de éxito

## 📚 Referencias

- MiniKit Docs: https://docs.world.org/mini-apps/commands/send-transaction
- LayerZero Scan: https://layerzeroscan.com/
