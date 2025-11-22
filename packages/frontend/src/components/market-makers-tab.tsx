"use client"
import { Plus, TrendingUp, ArrowRight, Droplet, Activity, Wallet, Layers } from "lucide-react"

interface Strategy {
  id: string
  name: string
  chainFrom: string
  chainTo: string
  liquidity: string
  apr: string
  status: "active" | "idle"
}

const mockStrategies: Strategy[] = [
  {
    id: "1",
    name: "ETH/USDC V3",
    chainFrom: "WorldChain",
    chainTo: "Base",
    liquidity: "$50,000",
    apr: "24.5%",
    status: "active",
  },
  {
    id: "2",
    name: "Stable Pool",
    chainFrom: "Base",
    chainTo: "WorldChain",
    liquidity: "$28,500",
    apr: "12.8%",
    status: "active",
  },
]

export function MarketMakersTab() {
  return (
    <div className="p-4 md:p-12 space-y-8">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
        <div>
          <h2 className="text-4xl md:text-5xl font-bold text-white tracking-tighter uppercase mb-2">Strategies</h2>
          <p className="text-gray-400 font-mono text-sm">Manage your cross-chain liquidity positions</p>
        </div>
        <button className="bg-white text-black px-6 py-3 font-bold uppercase tracking-wider border-2 border-white hover:bg-black hover:text-white transition-colors flex items-center gap-2 shadow-[4px_4px_0px_0px_#ffffff]">
          <Plus className="w-5 h-5" strokeWidth={2} />
          <span>Create Strategy</span>
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
        <div className="neo-card p-6">
          <div className="flex items-center justify-between mb-4">
            <span className="text-xs font-mono uppercase text-gray-400">Total Liquidity</span>
            <Wallet className="w-5 h-5 text-white" />
          </div>
          <div className="text-3xl font-bold text-white">$78,500.00</div>
          <div className="mt-2 text-sm text-green-400 font-mono flex items-center gap-1">
            <TrendingUp className="w-3 h-3" /> +12.5% this week
          </div>
        </div>

        <div className="neo-card p-6">
          <div className="flex items-center justify-between mb-4">
            <span className="text-xs font-mono uppercase text-gray-400">Avg. APR</span>
            <Activity className="w-5 h-5 text-white" />
          </div>
          <div className="text-3xl font-bold text-white">18.7%</div>
          <div className="mt-2 text-sm text-green-400 font-mono">Consistent Yield</div>
        </div>

        <div className="neo-card p-6">
          <div className="flex items-center justify-between mb-4">
            <span className="text-xs font-mono uppercase text-gray-400">Active Strategies</span>
            <Layers className="w-5 h-5 text-white" />
          </div>
          <div className="text-3xl font-bold text-white">2</div>
          <div className="mt-2 text-sm text-gray-400 font-mono">Across 2 Chains</div>
        </div>
      </div>

      <div className="space-y-6">
        <h3 className="text-xl font-bold text-white uppercase tracking-wider border-b-2 border-white/20 pb-4">
          Active Positions
        </h3>

        {mockStrategies.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {mockStrategies.map((strategy) => (
              <div key={strategy.id} className="neo-card p-6 hover:bg-white/5 group cursor-pointer relative">
                <div className="absolute top-4 right-4 flex items-center gap-2">
                  <div
                    className={`w-2 h-2 rounded-full ${strategy.status === "active" ? "bg-green-500 animate-pulse" : "bg-gray-500"}`}
                  />
                  <span className="text-xs font-mono uppercase text-gray-400">{strategy.status}</span>
                </div>

                <h4 className="text-2xl font-bold text-white mb-4 group-hover:underline decoration-2 underline-offset-4">
                  {strategy.name}
                </h4>

                <div className="flex items-center gap-3 mb-6">
                  <span className="px-3 py-1 border border-white/30 text-xs font-bold uppercase bg-white/5">
                    {strategy.chainFrom}
                  </span>
                  <ArrowRight className="w-4 h-4 text-gray-500" />
                  <span className="px-3 py-1 border border-white/30 text-xs font-bold uppercase bg-white/5">
                    {strategy.chainTo}
                  </span>
                </div>

                <div className="grid grid-cols-2 gap-4 border-t border-white/10 pt-4">
                  <div>
                    <div className="text-xs text-gray-500 font-mono uppercase mb-1">Liquidity</div>
                    <div className="text-xl font-bold">{strategy.liquidity}</div>
                  </div>
                  <div>
                    <div className="text-xs text-gray-500 font-mono uppercase mb-1">APR</div>
                    <div className="text-xl font-bold text-green-400">{strategy.apr}</div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="neo-card p-12 text-center border-dashed">
            <Droplet className="w-12 h-12 mx-auto mb-4 text-gray-600" />
            <h3 className="text-xl font-bold text-white mb-2">No Active Strategies</h3>
            <p className="text-gray-400 mb-6">Start earning yield by creating your first strategy</p>
            <button className="text-white underline underline-offset-4 hover:text-gray-300">Learn how it works</button>
          </div>
        )}
      </div>
    </div>
  )
}
