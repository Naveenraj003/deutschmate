import React from 'react'
import { Outlet } from 'react-router-dom'
import { Sidebar } from './Sidebar'
import { BottomNav } from './BottomNav'
import { DevStateToolbar } from './DevStateToolbar'

export const AppLayout: React.FC = () => {
  return (
    <div className="min-h-screen bg-[#FFF0F3] flex flex-col selection:bg-[#FF5C8D]/30 selection:text-[#4A0E2E]">
      <DevStateToolbar />
      <div className="flex-1 flex w-full">
        <Sidebar />
        <main
          id="main-content"
          className="flex-1 min-w-0 pb-24 md:pb-12 px-4 sm:px-6 lg:px-8 pt-6 max-w-5xl mx-auto w-full"
        >
          <Outlet />
        </main>
      </div>
      <BottomNav />
    </div>
  )
}
