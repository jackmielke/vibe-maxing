'use client'

import { useState } from 'react'
import { MiniKit, VerificationLevel, ISuccessResult } from '@worldcoin/minikit-js'

interface WorldIDAuthProps {
  onSuccess?: (nullifierHash: string) => void
  onError?: (error: string) => void
}

export default function WorldIDAuth({ onSuccess, onError }: WorldIDAuthProps) {
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleSignIn = async () => {
    setIsLoading(true)
    setError(null)

    try {
      console.log('🔐 Starting World ID verification...')

      const result = await MiniKit.commandsAsync.verify({
        action: 'login',
        verification_level: VerificationLevel.Orb,
      })

      console.log('📝 Verification result:', result)

      // Check if finalPayload has success status
      if (result.finalPayload && (result.finalPayload as any).status === 'success') {
        const payload = result.finalPayload as ISuccessResult
        console.log('✅ Verification successful!', payload)

        // Get wallet address after verification
        let walletAddress = null
        try {
          const walletAuth = await MiniKit.commandsAsync.walletAuth({
            nonce: Date.now().toString(),
            requestId: Date.now().toString(),
            expirationTime: new Date(Date.now() + 5 * 60 * 1000),
            notBefore: new Date(Date.now()),
            statement: 'Authenticate your wallet for Aqua0',
          })

          if (walletAuth.finalPayload && (walletAuth.finalPayload as any).status === 'success') {
            walletAddress = (walletAuth.finalPayload as any).address
            console.log('Wallet address:', walletAddress)
          }
        } catch (err) {
          console.warn('Could not get wallet address:', err)
        }

        // Guardar en localStorage
        localStorage.setItem(
          'worldid_auth',
          JSON.stringify({
            verified: true,
            nullifier_hash: payload.nullifier_hash,
            wallet_address: walletAddress,
          })
        )

        // Emitir evento personalizado
        window.dispatchEvent(
          new CustomEvent('worldid-verified', {
            detail: { nullifier_hash: payload.nullifier_hash },
          })
        )

        // Callback opcional
        if (onSuccess) {
          onSuccess(payload.nullifier_hash)
        }
      } else {
        console.error('❌ Verification failed:', result)
        const errorMessage = `Verification ${result.status}: ${JSON.stringify(result)}`
        setError(errorMessage)
        if (onError) {
          onError(errorMessage)
        }
      }
    } catch (err) {
      console.error('💥 Error during verification:', err)
      const errorMessage = err instanceof Error ? err.message : 'An error occurred during verification'
      setError(errorMessage)
      if (onError) {
        onError(errorMessage)
      }
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="flex flex-col items-center gap-4">
      <button
        onClick={handleSignIn}
        disabled={isLoading}
        className="bg-white text-black px-6 py-3 font-bold uppercase tracking-wider border-2 border-white hover:bg-black hover:text-white transition-colors flex items-center gap-2 shadow-[4px_4px_0px_0px_#ffffff] disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {isLoading ? (
          <>
            <div className="w-5 h-5 border-2 border-current border-t-transparent rounded-full animate-spin" />
            <span>Verifying...</span>
          </>
        ) : (
          <>
            <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
              <circle cx="12" cy="12" r="10" />
            </svg>
            <span>Sign in with World ID</span>
          </>
        )}
      </button>

      {error && (
        <div className="neo-card p-4 border-red-500 bg-red-950 text-red-200">
          <p className="text-sm font-mono">{error}</p>
        </div>
      )}
    </div>
  )
}
