import React from 'react'
import { useAuth } from '../../context/AuthContext'
import type { UIState } from '../../types/auth'

/**
 * DevStateToolbar: Controls mock role ('learner' <-> 'admin') and UI state previews.
 * RULE: Strictly gated behind import.meta.env.DEV so it is never included in production bundles.
 */
export const DevStateToolbar: React.FC = () => {
  // Never render in production
  if (!import.meta.env.DEV) {
    return null
  }

  const { user, toggleRole, uiState, setUIState } = useAuth()

  const states: UIState[] = ['normal', 'loading', 'empty', 'error']

  return (
    <aside
      aria-label="Development Mode Controls"
      className="bg-[#4A0E2E] text-white px-3 py-1.5 text-xs flex flex-wrap items-center justify-between gap-2 shadow-md z-50 sticky top-0"
    >
      <div className="flex items-center gap-2">
        <span className="bg-[#FF5C8D] text-white font-extrabold px-1.5 py-0.5 rounded text-[10px] tracking-wide uppercase">
          DEV ONLY
        </span>
        <span>
          Mock User:{' '}
          <strong className="text-pink-200">{user?.name || 'Logged Out'}</strong>
        </span>
        <button
          onClick={toggleRole}
          className="ml-2 px-2.5 py-1 bg-white/10 hover:bg-white/20 active:bg-white/30 rounded-lg font-medium transition-colors border border-white/20 text-[11px] touch-target-min flex items-center justify-center"
          title="Toggle between learner and admin role"
        >
          Toggle Role: <span className="ml-1 font-bold text-pink-300 uppercase">{user?.role}</span>
        </button>
      </div>

      <div className="flex items-center gap-1.5">
        <span className="text-pink-200 text-[11px]">Preview State:</span>
        {states.map((st) => (
          <button
            key={st}
            onClick={() => setUIState(st)}
            className={`px-2 py-0.5 rounded text-[11px] font-medium transition-all ${
              uiState === st
                ? 'bg-[#FF5C8D] text-white font-bold'
                : 'bg-white/10 hover:bg-white/20 text-pink-100'
            }`}
          >
            {st}
          </button>
        ))}
      </div>
    </aside>
  )
}
