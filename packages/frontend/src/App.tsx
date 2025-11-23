import { useState, useEffect } from "react"
import { Toaster } from "@/components/ui/toaster"
import { Toaster as Sonner } from "@/components/ui/sonner"
import { TooltipProvider } from "@/components/ui/tooltip"
import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { MarketMakersTab } from "@/components/market-makers-tab"
import { SwapTab } from "@/components/swap-tab"
import { LayoutGrid, ArrowLeftRight, HomeIcon, Zap, Globe, Layers } from "lucide-react"
import { DotLoader } from "@/components/ui/dot-loader"
import MiniKitProvider from "@/components/MiniKitProvider"
import WorldIDAuth from "@/components/WorldIDAuth"
import "./index.css"

const queryClient = new QueryClient()

const App = () => {
  const [activeTab, setActiveTab] = useState<"home" | "market-makers" | "swap">("home")
  const [showSplash, setShowSplash] = useState(true)
  const [isVerified, setIsVerified] = useState(false)

  useEffect(() => {
    // Check if user is already verified
    const authData = localStorage.getItem('worldid_auth')
    if (authData) {
      const { verified } = JSON.parse(authData)
      setIsVerified(verified)
    }
  }, [])

  const game = [
    [14, 7, 0, 8, 6, 13, 20],
    [14, 7, 13, 20, 16, 27, 21],
    [14, 20, 27, 21, 34, 24, 28],
    [27, 21, 34, 28, 41, 32, 35],
    [34, 28, 41, 35, 48, 40, 42],
    [34, 28, 41, 35, 48, 42, 46],
    [34, 28, 41, 35, 48, 42, 38],
    [34, 28, 41, 48, 21, 22, 14],
    [34, 28, 41, 21, 14, 16, 27],
    [34, 28, 21, 14, 10, 20, 27],
    [28, 21, 14, 4, 13, 20, 27],
    [28, 21, 14, 12, 6, 13, 20],
    [28, 21, 14, 6, 13, 20, 11],
    [28, 21, 14, 6, 13, 20, 10],
    [14, 6, 13, 20, 9, 7, 21],
  ]

  useEffect(() => {
    const timer = setTimeout(() => {
      setShowSplash(false)
    }, 2500)
    return () => clearTimeout(timer)
  }, [])

  if (showSplash) {
    return (
      <MiniKitProvider>
        <QueryClientProvider client={queryClient}>
          <TooltipProvider>
            <Toaster />
            <Sonner />
            <div className="fixed inset-0 z-[100] flex flex-col items-center justify-center bg-black space-bg">
              <div className="relative z-10 flex flex-col items-center gap-8 animate-in fade-in zoom-in duration-700">
                <h1 className="text-4xl md:text-6xl font-bold tracking-tighter text-white font-space uppercase">AquaZero</h1>
                <DotLoader
                  frames={game}
                  className="gap-1 scale-150"
                  dotClassName="bg-white/15 [&.active]:bg-white size-2"
                  duration={80}
                />
              </div>
            </div>
          </TooltipProvider>
        </QueryClientProvider>
      </MiniKitProvider>
    )
  }

  return (
    <MiniKitProvider>
      <QueryClientProvider client={queryClient}>
        <TooltipProvider>
          <Toaster />
          <Sonner />
        <main className="min-h-screen bg-black text-white font-sans space-bg pb-24 md:pb-0 md:pl-64 relative overflow-hidden">
          {/* Desktop Sidebar */}
          <aside className="hidden md:flex fixed left-0 top-0 bottom-0 w-64 bg-black border-r-2 border-white flex-col z-50">
            <div className="p-6 border-b-2 border-white">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 border-2 border-white bg-black flex items-center justify-center">
                  <img
                    src="/aqua0-logo.png"
                    alt="Aqua0 Logo"
                    width={32}
                    height={32}
                    className="w-8 h-8 object-contain invert"
                  />
                </div>
                <h1 className="text-2xl font-bold tracking-tighter">AQUA0</h1>
              </div>
            </div>

            <nav className="flex-1 p-6 space-y-4">
              <button
                onClick={() => setActiveTab("home")}
                className={`w-full flex items-center gap-4 px-4 py-4 border-2 transition-all duration-200 group ${
                  activeTab === "home"
                    ? "bg-white text-black border-white shadow-[4px_4px_0px_0px_#ffffff]"
                    : "bg-black text-white border-transparent hover:border-white hover:shadow-[4px_4px_0px_0px_#ffffff]"
                }`}
              >
                <HomeIcon className="w-5 h-5" strokeWidth={2} />
                <span className="font-bold tracking-wide uppercase">Home</span>
              </button>

              <button
                onClick={() => setActiveTab("market-makers")}
                className={`w-full flex items-center gap-4 px-4 py-4 border-2 transition-all duration-200 group ${
                  activeTab === "market-makers"
                    ? "bg-white text-black border-white shadow-[4px_4px_0px_0px_#ffffff]"
                    : "bg-black text-white border-transparent hover:border-white hover:shadow-[4px_4px_0px_0px_#ffffff]"
                }`}
              >
                <LayoutGrid className="w-5 h-5" strokeWidth={2} />
                <span className="font-bold tracking-wide uppercase">Strategies</span>
              </button>

              <button
                onClick={() => setActiveTab("swap")}
                className={`w-full flex items-center gap-4 px-4 py-4 border-2 transition-all duration-200 group ${
                  activeTab === "swap"
                    ? "bg-white text-black border-white shadow-[4px_4px_0px_0px_#ffffff]"
                    : "bg-black text-white border-transparent hover:border-white hover:shadow-[4px_4px_0px_0px_#ffffff]"
                }`}
              >
                <ArrowLeftRight className="w-5 h-5" strokeWidth={2} />
                <span className="font-bold tracking-wide uppercase">Swap</span>
              </button>
            </nav>

            <div className="p-6 border-t-2 border-white">
              <div className="text-xs font-mono text-gray-400 text-center">AQUA0 V1.0 // WORLDCHAIN</div>
            </div>
          </aside>

          {/* Mobile Header */}
          <header className="md:hidden fixed top-0 left-0 right-0 bg-black border-b-2 border-white z-40 p-4">
            <div className="flex items-center justify-center gap-3">
              <div className="w-8 h-8 border-2 border-white flex items-center justify-center bg-black">
                <img
                  src="/aqua0-logo.png"
                  alt="Aqua0 Logo"
                  width={20}
                  height={20}
                  className="w-5 h-5 object-contain invert"
                />
              </div>
              <h1 className="text-xl font-bold tracking-tighter">AQUA0</h1>
            </div>
          </header>

          {/* Main Content Area */}
          <div className="pt-20 md:pt-0 min-h-screen">
            {activeTab === "home" && (
              <div className="max-w-5xl mx-auto p-6 md:p-12 animate-in fade-in slide-in-from-bottom-4 duration-500">
                {/* Hero Section */}
                <section className="mb-16 md:mb-24 pt-8 md:pt-16 text-center md:text-left">
                  <div className="inline-block mb-6 px-3 py-1 border border-white text-xs font-mono uppercase tracking-widest animate-pulse">
                    Cross-Chain Liquidity Protocol
                  </div>
                  <h1 className="text-5xl md:text-8xl font-bold leading-[0.9] tracking-tighter mb-8 uppercase">
                    Liquidity <br />
                    <span className="text-transparent bg-clip-text bg-gradient-to-r from-white to-gray-500">Unbound</span>
                  </h1>
                  <p className="text-lg md:text-xl text-gray-300 max-w-2xl leading-relaxed font-light mb-10">
                    Solve the capital fragmentation problem. Allocate the same capital to multiple trading strategies across
                    different blockchains simultaneously.
                  </p>

                  <div className="flex flex-col md:flex-row gap-4 mb-8">
                    <button
                      onClick={() => setActiveTab("market-makers")}
                      className="bg-white text-black border-2 border-white px-8 py-4 text-lg font-bold uppercase tracking-wider shadow-[6px_6px_0px_0px_#333] hover:translate-x-[2px] hover:translate-y-[2px] hover:shadow-[2px_2px_0px_0px_#333] transition-all"
                    >
                      Launch App
                    </button>
                    <button className="bg-transparent text-white border-2 border-white px-8 py-4 text-lg font-bold uppercase tracking-wider hover:bg-white hover:text-black transition-colors">
                      Read Docs
                    </button>
                  </div>

                  {/* World ID Auth Section */}
                  <div className="p-6 neo-card inline-block">
                    <div className="mb-4">
                      <h3 className="text-xl font-bold text-white mb-2">Connect with World ID</h3>
                      <p className="text-sm text-gray-400">Verify your humanity to access the protocol</p>
                    </div>
                    <WorldIDAuth
                      onSuccess={(nullifierHash) => {
                        console.log('Verified!', nullifierHash)
                        setIsVerified(true)
                      }}
                      onError={(error) => {
                        console.error('Verification failed:', error)
                      }}
                    />
                    {isVerified && (
                      <div className="mt-4 p-3 bg-green-950 border-2 border-green-500 rounded text-green-200 text-sm font-mono">
                        ✓ Verified with World ID
                      </div>
                    )}
                  </div>
                </section>

                {/* Features Grid */}
                <section className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-20">
                  <div className="neo-card p-8 relative group">
                    <div className="absolute top-4 right-4">
                      <Globe className="w-8 h-8" strokeWidth={1.5} />
                    </div>
                    <h3 className="text-2xl font-bold mb-4 mt-4 uppercase">Cross-Chain</h3>
                    <p className="text-gray-400 leading-relaxed">
                      Capital stays in your wallet. Tokens move via LayerZero only when needed for execution.
                    </p>
                  </div>

                  <div className="neo-card p-8 relative group">
                    <div className="absolute top-4 right-4">
                      <Layers className="w-8 h-8" strokeWidth={1.5} />
                    </div>
                    <h3 className="text-2xl font-bold mb-4 mt-4 uppercase">SLAC Model</h3>
                    <p className="text-gray-400 leading-relaxed">
                      Shared Liquidity Amplification Coefficient. Achieve 3-10x capital efficiency.
                    </p>
                  </div>

                  <div className="neo-card p-8 relative group">
                    <div className="absolute top-4 right-4">
                      <Zap className="w-8 h-8" strokeWidth={1.5} />
                    </div>
                    <h3 className="text-2xl font-bold mb-4 mt-4 uppercase">Auto-Compound</h3>
                    <p className="text-gray-400 leading-relaxed">
                      Profits and fees are automatically pushed back to your wallet and compounded.
                    </p>
                  </div>
                </section>

                {/* How it Works */}
                <section className="border-t-2 border-white pt-16">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-12 items-center">
                    <div>
                      <h2 className="text-4xl font-bold mb-8 uppercase tracking-tight">How It Works</h2>
                      <div className="space-y-8">
                        <div className="flex gap-6">
                          <div className="text-4xl font-bold opacity-30">01</div>
                          <div>
                            <h4 className="text-xl font-bold mb-2 uppercase">Define Strategy</h4>
                            <p className="text-gray-400">
                              Create liquidity strategies for Uniswap on Base using your WorldChain capital.
                            </p>
                          </div>
                        </div>
                        <div className="flex gap-6">
                          <div className="text-4xl font-bold opacity-30">02</div>
                          <div>
                            <h4 className="text-xl font-bold mb-2 uppercase">Ship Capital</h4>
                            <p className="text-gray-400">
                              Virtual accounting updates your position. No initial token movement required.
                            </p>
                          </div>
                        </div>
                        <div className="flex gap-6">
                          <div className="text-4xl font-bold opacity-30">03</div>
                          <div>
                            <h4 className="text-xl font-bold mb-2 uppercase">Earn Yield</h4>
                            <p className="text-gray-400">
                              Trades execute against your strategies. Fees accrue in real-time.
                            </p>
                          </div>
                        </div>
                      </div>
                    </div>
                    <div className="neo-card aspect-square flex items-center justify-center p-12 relative overflow-hidden">
                      <div className="absolute inset-0 opacity-20 bg-[radial-gradient(circle_at_center,_var(--tw-gradient-stops))] from-white via-transparent to-transparent"></div>
                      <img
                        src="/aqua0-logo.png"
                        alt="Aqua0 Diagram"
                        width={200}
                        height={200}
                        className="w-32 h-32 md:w-48 md:h-48 object-contain invert animate-pulse"
                      />
                    </div>
                  </div>
                </section>
              </div>
            )}

            {activeTab === "market-makers" && (
              <div className="max-w-7xl mx-auto animate-in fade-in slide-in-from-bottom-4 duration-500">
                <MarketMakersTab />
              </div>
            )}

            {activeTab === "swap" && (
              <div className="max-w-3xl mx-auto animate-in fade-in slide-in-from-bottom-4 duration-500">
                <SwapTab />
              </div>
            )}
          </div>

          {/* Mobile Bottom Navigation */}
          <nav className="fixed bottom-0 left-0 right-0 bg-black border-t-2 border-white z-50 md:hidden">
            <div className="grid grid-cols-3 h-20">
              <button
                onClick={() => setActiveTab("home")}
                className={`flex flex-col items-center justify-center gap-1 border-r-2 border-white/20 transition-colors ${
                  activeTab === "home" ? "bg-white text-black" : "text-white hover:bg-white/10"
                }`}
              >
                <HomeIcon className="w-6 h-6" strokeWidth={2} />
                <span className="text-[10px] font-bold uppercase tracking-wider">Home</span>
              </button>
              <button
                onClick={() => setActiveTab("market-makers")}
                className={`flex flex-col items-center justify-center gap-1 border-r-2 border-white/20 transition-colors ${
                  activeTab === "market-makers" ? "bg-white text-black" : "text-white hover:bg-white/10"
                }`}
              >
                <LayoutGrid className="w-6 h-6" strokeWidth={2} />
                <span className="text-[10px] font-bold uppercase tracking-wider">Strategies</span>
              </button>
              <button
                onClick={() => setActiveTab("swap")}
                className={`flex flex-col items-center justify-center gap-1 transition-colors ${
                  activeTab === "swap" ? "bg-white text-black" : "text-white hover:bg-white/10"
                }`}
              >
                <ArrowLeftRight className="w-6 h-6" strokeWidth={2} />
                <span className="text-[10px] font-bold uppercase tracking-wider">Swap</span>
              </button>
            </div>
          </nav>
        </main>
        </TooltipProvider>
      </QueryClientProvider>
    </MiniKitProvider>
  )
}

export default App
