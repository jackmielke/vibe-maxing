'use client'

import { ReactNode, useEffect } from 'react'
import { MiniKit } from '@worldcoin/minikit-js'

const APP_ID = import.meta.env.VITE_WORLD_APP_ID || 'app_95353fdbbdc556589a013271729e7378'

export default function MiniKitProvider({ children }: { children: ReactNode }) {
  useEffect(() => {
    MiniKit.install(APP_ID)
  }, [])

  return <>{children}</>
}
