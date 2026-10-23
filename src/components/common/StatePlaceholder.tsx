import React from 'react'
import type { UIState } from '../../types/auth'
import { AlertCircleIcon, RotateCcwIcon, SparklesIcon } from '../icons'

interface StatePlaceholderProps {
  state: UIState
  emptyMessage?: string
  tamilEmptyMessage?: string
  errorMessage?: string
  onRetry?: () => void
  children?: React.ReactNode
}

export const StatePlaceholder: React.FC<StatePlaceholderProps> = ({
  state,
  emptyMessage = 'No items found yet.',
  tamilEmptyMessage = 'இன்னும் எந்த உருப்படிகளும் கிடைக்கவில்லை.',
  errorMessage = 'Something went wrong while fetching data.',
  onRetry,
  children
}) => {
  if (state === 'loading') {
    return (
      <div className="py-12 flex flex-col items-center justify-center text-center space-y-4 animate-pulse">
        <div className="w-12 h-12 rounded-full border-4 border-[#FF5C8D]/20 border-t-[#C72A63] animate-spin" />
        <div>
          <p className="text-base font-semibold text-[#4A0E2E]">Lade Deutsch-Lektionen...</p>
          <p className="text-xs text-[#7A3556] mt-0.5">Loading German lessons...</p>
          <p className="text-xs text-[#7A3556] font-tamil">பாடம் ஏற்றப்படுகிறது...</p>
        </div>
      </div>
    )
  }

  if (state === 'empty') {
    return (
      <div className="py-10 px-4 flex flex-col items-center justify-center text-center bg-[#FFF0F3]/60 rounded-2xl border border-[#FF5C8D]/20">
        <div className="w-12 h-12 rounded-2xl bg-white shadow-xs flex items-center justify-center text-[#FF5C8D] mb-3">
          <SparklesIcon className="w-6 h-6" />
        </div>
        <h4 className="text-base font-bold text-[#4A0E2E]">{emptyMessage}</h4>
        <p className="text-xs text-[#7A3556] font-tamil mt-1">{tamilEmptyMessage}</p>
        <p className="text-xs text-[#7A3556] mt-2 max-w-xs">
          Explore or check back in a moment to begin your daily journey.
        </p>
      </div>
    )
  }

  if (state === 'error') {
    return (
      <div className="py-8 px-4 flex flex-col items-center justify-center text-center bg-rose-50/80 rounded-2xl border border-rose-200">
        <div className="w-12 h-12 rounded-2xl bg-white text-rose-500 shadow-xs flex items-center justify-center mb-3">
          <AlertCircleIcon className="w-6 h-6" />
        </div>
        <h4 className="text-base font-bold text-[#4A0E2E]">{errorMessage}</h4>
        <p className="text-xs text-rose-700 font-tamil mt-1">பிழை ஏற்பட்டது, மீண்டும் முயற்சிக்கவும்.</p>
        {onRetry && (
          <button
            onClick={onRetry}
            className="mt-4 inline-flex items-center gap-2 px-4 py-2 bg-[#C72A63] hover:bg-[#A82253] text-white text-xs font-semibold rounded-xl transition-colors shadow-xs touch-target-min"
          >
            <RotateCcwIcon className="w-4 h-4" />
            Retry / மீண்டும் முயற்சி செய்
          </button>
        )}
      </div>
    )
  }

  return <>{children}</>
}
