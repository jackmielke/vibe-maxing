"use client"

import { useState, useEffect } from "react"
import { ArrowDown, Check, Info, Sparkles } from "lucide-react"
import { DotLoader } from "@/components/ui/dot-loader"

interface Token {
  symbol: string
  name: string
  balance: string
  icon: string
}

const tokens: Token[] = [
  { symbol: "ETH", name: "Ethereum", balance: "2.5", icon: "⟠" },
  { symbol: "USDC", name: "USD Coin", balance: "1,250.00", icon: "$" },
  { symbol: "USDT", name: "Tether", balance: "840.50", icon: "₮" },
  { symbol: "WLD", name: "Worldcoin", balance: "156.2", icon: "◎" },
]

const PING_PONG_FRAMES = [
  [2, 6, 10, 14, 17, 18, 19, 20, 21, 25, 29, 33, 37, 41, 43, 44, 45, 46, 47],
  [2, 6, 10, 14, 18, 22, 23, 24, 25, 26, 29, 33, 37, 41, 43, 44, 45, 46, 47],
  [2, 6, 10, 14, 18, 22, 27, 28, 29, 30, 29, 33, 37, 41, 43, 44, 45, 46, 47],
  [2, 6, 10, 14, 18, 22, 26, 32, 33, 34, 37, 41, 43, 44, 45, 46, 47],
  [2, 6, 10, 14, 18, 22, 26, 30, 37, 38, 41, 43, 44, 45, 46, 47],
  [2, 6, 10, 14, 18, 22, 26, 30, 34, 42, 43, 44, 45, 46, 47],
  [2, 6, 10, 14, 18, 22, 26, 30, 34, 38, 42, 46, 43, 44, 45, 47],
  [2, 6, 10, 14, 18, 22, 26, 30, 34, 38, 42, 46, 45],
  [2, 6, 10, 14, 18, 22, 26, 30, 34, 38, 42, 46, 43, 44, 45, 47],
  [2, 6, 10, 14, 18, 22, 26, 30, 37, 38, 41, 43, 44, 45, 46, 47],
  [2, 6, 10, 14, 18, 22, 27, 28, 29, 30, 33, 37, 41, 43, 44, 45, 46, 47],
  [2, 6, 10, 14, 18, 22, 23, 24, 25, 26, 29, 33, 37, 41, 43, 44, 45, 46, 47],
]

export function SwapTab() {
  const [fromToken, setFromToken] = useState(tokens[0])
  const [toToken, setToToken] = useState(tokens[1])
  const [fromAmount, setFromAmount] = useState("")
  const [isSwapping, setIsSwapping] = useState(false)
  const [isCompleted, setIsCompleted] = useState(false)
  const [progress, setProgress] = useState(0)

  const toAmount = fromAmount ? (Number.parseFloat(fromAmount) * 2842.5).toFixed(2) : ""

  const handleSwap = () => {
    window.scrollTo({ top: 0, behavior: "smooth" })
    setIsSwapping(true)
    setProgress(0)
  }

  useEffect(() => {
    if (!isSwapping) return

    const totalDuration = 10000 // 10 seconds
    const intervalTime = 100
    const steps = totalDuration / intervalTime
    let currentStep = 0

    const timer = setInterval(() => {
      currentStep++
      const newProgress = Math.min((currentStep / steps) * 100, 100)
      setProgress(newProgress)

      if (currentStep >= steps) {
        clearInterval(timer)
        setIsSwapping(false)
        setIsCompleted(true)
        window.scrollTo({ top: 0, behavior: "smooth" })

        setTimeout(() => {
          setIsCompleted(false)
          setFromAmount("")
        }, 2000)
      }
    }, intervalTime)

    return () => clearInterval(timer)
  }, [isSwapping])

  return (
    <div className="p-4 md:p-12 flex flex-col justify-center min-h-[60vh] relative">
      {(isSwapping || isCompleted) && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/95 backdrop-blur-sm animate-in fade-in duration-200">
          <div className="w-full max-w-md p-8 mx-4">
            <div className="neo-card bg-black border-2 border-white p-8 relative overflow-hidden text-center space-y-6 shadow-[8px_8px_0px_0px_#fff]">
              {/* Background decorative elements */}
              <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,_var(--tw-gradient-stops))] from-white/10 via-transparent to-transparent opacity-50" />
              <div className="absolute top-4 left-4 animate-pulse">
                <Sparkles className="w-6 h-6 text-white/60" />
              </div>
              <div className="absolute bottom-4 right-4 animate-pulse delay-700">
                <Sparkles className="w-6 h-6 text-white/60" />
              </div>

              <div className="relative z-10 flex flex-col items-center gap-6 min-h-[300px] justify-center">
                {isSwapping ? (
                  <>
                    <div className="scale-150 mb-4">
                      <DotLoader
                        frames={PING_PONG_FRAMES}
                        isPlaying={true}
                        dotClassName="bg-white/20 [&.active]:bg-white w-1 h-1"
                        className="gap-1"
                      />
                    </div>

                    <div className="space-y-4 w-full">
                      <h2 className="text-3xl font-bold text-white uppercase tracking-tighter animate-pulse">
                        Swapping...
                      </h2>

                      <div className="w-full bg-white/10 h-4 border border-white/20 relative overflow-hidden">
                        <div
                          className="h-full bg-white transition-all duration-100 ease-linear"
                          style={{ width: `${progress}%` }}
                        />
                      </div>
                      <p className="text-gray-400 font-mono text-sm">{Math.round(progress)}%</p>
                    </div>
                  </>
                ) : (
                  <>
                    <div className="w-20 h-20 bg-white rounded-full flex items-center justify-center animate-in zoom-in duration-300">
                      <Check className="w-10 h-10 text-black" strokeWidth={4} />
                    </div>

                    <div className="space-y-2">
                      <h2 className="text-3xl font-bold text-white uppercase tracking-tighter">Swap Complete</h2>
                      <p className="text-gray-400 font-mono">Transaction confirmed</p>
                    </div>
                  </>
                )}

                <div className="w-full py-4 border-t border-b border-white/20 mt-auto">
                  <p className="text-xl text-white font-bold flex items-center justify-center gap-2 flex-wrap">
                    <span>
                      {fromAmount} {fromToken.symbol}
                    </span>
                    <span className="text-gray-500">→</span>
                    <span>
                      {toAmount} {toToken.symbol}
                    </span>
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      <div className="max-w-xl mx-auto w-full space-y-8">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-4xl font-bold text-white tracking-tighter uppercase mb-1">Swap</h2>
            <div className="h-1 w-12 bg-white"></div>
          </div>
        </div>

        <div className="neo-card p-1 relative bg-black">
          {/* From Token */}
          <div className="p-6 space-y-4">
            <div className="flex justify-between items-start">
              <div className="flex flex-col gap-1">
                <span className="text-sm font-mono text-gray-400">FROM</span>
              </div>
              <button className="flex items-center gap-2 bg-white text-black px-4 py-2 font-bold border-2 border-white hover:bg-gray-200 transition-colors min-w-[120px] justify-center">
                <span className="text-lg">{fromToken.icon}</span>
                <span>{fromToken.symbol}</span>
              </button>
            </div>

            <div className="w-full py-2">
              <input
                type="text"
                value={fromAmount}
                onChange={(e) => setFromAmount(e.target.value)}
                placeholder="0.0"
                className="w-full bg-transparent text-6xl font-bold text-white placeholder-gray-700 outline-none tracking-tighter"
              />
            </div>

            <div className="flex justify-between items-center pt-2">
              <span className="text-sm text-gray-500">$ --</span>
              <span className="text-sm font-mono text-gray-400">BAL: {fromToken.balance}</span>
            </div>
          </div>

          {/* Divider & Swap Button */}
          <div className="relative h-2 bg-black my-2 flex items-center justify-center">
            <div className="absolute h-[1px] w-full bg-white/20"></div>
            <button
              onClick={() => {
                setFromToken(toToken)
                setToToken(fromToken)
              }}
              className="z-10 bg-black border-2 border-white p-2 hover:bg-white hover:text-black transition-colors rounded-full"
            >
              <ArrowDown className="w-5 h-5" strokeWidth={3} />
            </button>
          </div>

          {/* To Token */}
          <div className="p-6 space-y-4">
            <div className="flex justify-between items-start">
              <div className="flex flex-col gap-1">
                <span className="text-sm font-mono text-gray-400">TO (ESTIMATED)</span>
              </div>
              <button className="flex items-center gap-2 bg-black text-white px-4 py-2 font-bold border-2 border-white hover:bg-white/10 transition-colors min-w-[120px] justify-center">
                <span className="text-lg">{toToken.icon}</span>
                <span>{toToken.symbol}</span>
              </button>
            </div>

            <div className="w-full py-2">
              <div
                className={`text-6xl font-bold tracking-tighter break-all ${toAmount ? "text-white" : "text-gray-700"}`}
              >
                {toAmount || "0.0"}
              </div>
            </div>

            <div className="flex justify-between items-center pt-2">
              <span className="text-sm text-gray-500">$ --</span>
              <span className="text-sm font-mono text-gray-400">BAL: {toToken.balance}</span>
            </div>
          </div>
        </div>

        {/* Route Info */}
        {fromAmount && (
          <div className="neo-card p-4 space-y-3 animate-in fade-in slide-in-from-top-2">
            <div className="flex justify-between text-sm">
              <span className="text-gray-400 font-mono">Rate</span>
              <span className="text-white font-bold">
                1 {fromToken.symbol} = 2,842.5 {toToken.symbol}
              </span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400 font-mono flex items-center gap-1">
                Network Fee <Info className="w-3 h-3" />
              </span>
              <span className="text-white font-bold">~$2.40</span>
            </div>
          </div>
        )}

        <button
          onClick={handleSwap}
          disabled={!fromAmount || isSwapping}
          className="w-full bg-white text-black font-bold text-xl py-6 border-2 border-white shadow-[6px_6px_0px_0px_#333] hover:translate-x-[2px] hover:translate-y-[2px] hover:shadow-[2px_2px_0px_0px_#333] active:translate-x-[6px] active:translate-y-[6px] active:shadow-none transition-all disabled:opacity-50 disabled:cursor-not-allowed uppercase tracking-widest flex items-center justify-center gap-3"
        >
          {!fromAmount ? "Enter Amount" : "Swap Tokens"}
        </button>
      </div>
    </div>
  )
}
