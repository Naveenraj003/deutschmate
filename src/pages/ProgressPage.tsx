import React from 'react'
import { useAuth } from '../context/AuthContext'
import { StitchedCard } from '../components/common/StitchedCard'
import { StatePlaceholder } from '../components/common/StatePlaceholder'
import { BarChart2Icon } from '../components/icons'

export const ProgressPage: React.FC = () => {
  const { uiState } = useAuth()

  const stats = [
    { label: 'Words Learned', value: '42', tamil: 'கற்ற சொற்கள்' },
    { label: 'Study Streak', value: '3 Days', tamil: 'தொடர் கற்றல்' },
    { label: 'Accuracy', value: '94%', tamil: 'துல்லியம்' },
    { label: 'Level', value: 'A1 Beginner', tamil: 'தொடக்க நிலை' }
  ]

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl sm:text-3xl font-extrabold text-[#4A0E2E] tracking-tight">
          Your Progress & Milestones
        </h1>
        <p className="text-xs sm:text-sm text-[#7A3556] mt-0.5">
          Track vocabulary mastery, streaks, and CEFR progress
        </p>
        <p className="text-xs text-[#FF5C8D] font-tamil">
          உங்கள் கற்றல் முன்னேற்றத்தைக் கண்காணிக்கவும்
        </p>
      </div>

      {/* The single stitched card for this screen */}
      <StitchedCard
        title="Learning Metrics"
        subtitle="Summary of your German practice this week"
        tamilSubtitle="இந்த வார கற்றல் புள்ளிவிவரங்கள்"
      >
        <StatePlaceholder
          state={uiState}
          emptyMessage="No progress activity recorded yet."
          tamilEmptyMessage="இன்னும் எந்த முன்னேற்றத் தரவும் பதிவாகவில்லை."
        >
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            {stats.map((item, idx) => (
              <div
                key={idx}
                className="p-4 rounded-2xl bg-[#FFF0F3]/60 border border-pink-100 text-center"
              >
                <p className="text-2xl sm:text-3xl font-extrabold text-[#C72A63]">
                  {item.value}
                </p>
                <p className="text-xs font-bold text-[#4A0E2E] mt-1">{item.label}</p>
                <p className="text-[11px] text-[#7A3556] font-tamil">{item.tamil}</p>
              </div>
            ))}
          </div>
        </StatePlaceholder>
      </StitchedCard>

      {/* Secondary unstitched card */}
      <div className="bg-white rounded-3xl p-6 border border-pink-100 shadow-xs">
        <h3 className="text-base font-bold text-[#4A0E2E] mb-2 flex items-center gap-2">
          <BarChart2Icon className="w-5 h-5 text-[#FF5C8D]" />
          <span>Curriculum Mastery: CEFR A1.1</span>
        </h3>
        <div className="w-full bg-[#FFF0F3] rounded-full h-3 overflow-hidden border border-pink-100">
          <div
            className="bg-gradient-to-r from-[#FF5C8D] to-[#C72A63] h-full rounded-full transition-all duration-500"
            style={{ width: '35%' }}
          />
        </div>
        <p className="text-xs text-[#7A3556] mt-2">
          35% completed • 7 lessons remaining in Chapter 1
        </p>
      </div>
    </div>
  )
}
