"use client"
import { ArrowLeft, Plus, Minus, Pause } from "lucide-react"

interface StrategyDetailProps {
  strategyId: string
  onBack: () => void
}

// Mock data - will be replaced with real data later
const mockStrategyData = {
  "1": {
    name: "ETH/USDC V3",
    chain: "Base",
    status: "active" as const,
    liquidity: "$12,450",
    feesEarned: "$342",
  },
  "2": {
    name: "Stable Pool",
    chain: "WorldChain",
    status: "active" as const,
    liquidity: "$8,200",
    feesEarned: "$156",
  },
}

export function StrategyDetail({ strategyId, onBack }: StrategyDetailProps) {
  const strategy = mockStrategyData[strategyId as keyof typeof mockStrategyData] || mockStrategyData["1"]

  return (
    <div className="p-4 md:p-12 space-y-8 animate-in fade-in slide-in-from-right-4 duration-500">
      {/* Header */}
      <div className="space-y-6">
        <button
          onClick={onBack}
          className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors group"
        >
          <ArrowLeft className="w-5 h-5 group-hover:-translate-x-1 transition-transform" strokeWidth={2} />
          <span className="font-mono text-sm uppercase tracking-wider">Back to Strategies</span>
        </button>

        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div className="space-y-3">
            <h2 className="text-4xl md:text-5xl font-bold text-white tracking-tighter uppercase">
              {strategy.name}
            </h2>
            <div className="flex items-center gap-3">
              <span className="px-3 py-1 border border-white/30 text-xs font-bold uppercase bg-white/5">
                {strategy.chain}
              </span>
              <div className="flex items-center gap-2">
                <div
                  className={`w-2 h-2 rounded-full ${
                    strategy.status === "active" ? "bg-green-500 animate-pulse" : "bg-yellow-500"
                  }`}
                />
                <span className="text-xs font-mono uppercase text-gray-400">
                  {strategy.status}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Metrics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="neo-card p-6">
          <div className="flex items-center justify-between mb-4">
            <span className="text-xs font-mono uppercase text-gray-400">Your Liquidity</span>
          </div>
          <div className="text-4xl font-bold text-white mb-2">{strategy.liquidity}</div>
          <div className="text-sm text-gray-400 font-mono">Deployed capital</div>
        </div>

        <div className="neo-card p-6">
          <div className="flex items-center justify-between mb-4">
            <span className="text-xs font-mono uppercase text-gray-400">Fees Earned</span>
          </div>
          <div className="text-4xl font-bold text-white mb-2">{strategy.feesEarned}</div>
          <div className="text-sm text-gray-400 font-mono">Total fees collected</div>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="neo-card p-8">
        <h3 className="text-xl font-bold text-white uppercase tracking-wider mb-6">Actions</h3>
        <div className="space-y-4">
          {/* Add Liquidity */}
          <button className="w-full bg-white text-black px-6 py-4 font-bold uppercase tracking-wider border-2 border-white hover:bg-black hover:text-white transition-colors flex items-center justify-center gap-3 shadow-[4px_4px_0px_0px_#ffffff] hover:shadow-[2px_2px_0px_0px_#ffffff] hover:translate-x-[2px] hover:translate-y-[2px]">
            <Plus className="w-5 h-5" strokeWidth={2} />
            <span>Add Liquidity</span>
          </button>

          {/* Remove Liquidity */}
          <button className="w-full bg-black text-white px-6 py-4 font-bold uppercase tracking-wider border-2 border-white hover:bg-white hover:text-black transition-colors flex items-center justify-center gap-3">
            <Minus className="w-5 h-5" strokeWidth={2} />
            <span>Remove Liquidity</span>
          </button>

          {/* Pause Strategy */}
          <button className="w-full text-red-400 hover:text-red-300 py-4 font-mono text-sm uppercase tracking-wider flex items-center justify-center gap-2 transition-colors group">
            <Pause className="w-4 h-4 group-hover:scale-110 transition-transform" strokeWidth={2} />
            <span>Pause Strategy</span>
          </button>
        </div>
      </div>

      {/* Strategy Details */}
      <div className="neo-card p-8">
        <h3 className="text-xl font-bold text-white uppercase tracking-wider mb-6 border-b-2 border-white/20 pb-4">
          Strategy Details
        </h3>
        <div className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <div className="text-xs text-gray-500 font-mono uppercase mb-2">Pool Type</div>
              <div className="text-lg font-bold text-white">Uniswap V3</div>
            </div>
            <div>
              <div className="text-xs text-gray-500 font-mono uppercase mb-2">Fee Tier</div>
              <div className="text-lg font-bold text-white">0.30%</div>
            </div>
            <div>
              <div className="text-xs text-gray-500 font-mono uppercase mb-2">Price Range</div>
              <div className="text-lg font-bold text-white">$2,850 - $3,150</div>
            </div>
            <div>
              <div className="text-xs text-gray-500 font-mono uppercase mb-2">Created</div>
              <div className="text-lg font-bold text-white">2 days ago</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
