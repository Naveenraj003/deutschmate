import React from 'react'
import { useAuth } from '../context/AuthContext'
import { StitchedCard } from '../components/common/StitchedCard'
import { StatePlaceholder } from '../components/common/StatePlaceholder'
import { RotateCcwIcon, SparklesIcon } from '../components/icons'

export const ReviewPage: React.FC = () => {
  const { uiState } = useAuth()

  const reviewCards = [
    {
      german: 'Guten Morgen',
      english: 'Good morning',
      tamil: 'காலை வணக்கம்',
      due: 'Today'
    },
    {
      german: 'Auf Wiedersehen',
      english: 'Goodbye / See you again',
      tamil: 'மீண்டும் சந்திப்போம்',
      due: 'Tomorrow'
    },
    {
      german: 'Danke schön',
      english: 'Thank you very much',
      tamil: 'மிக்க நன்றி',
      due: 'In 3 days'
    }
  ]

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl sm:text-3xl font-extrabold text-[#4A0E2E] tracking-tight">
          Review & Flashcards
        </h1>
        <p className="text-xs sm:text-sm text-[#7A3556] mt-0.5">
          Spaced repetition practice to build lasting memory
        </p>
        <p className="text-xs text-[#FF5C8D] font-tamil">
          மறதிக்கு முற்றுப்புள்ளி வைக்கும் நினைவூட்டல் பயிற்சி
        </p>
      </div>

      {/* The single stitched card for this screen */}
      <StitchedCard
        title="Spaced Repetition Deck"
        subtitle="Review 3 German phrases due today"
        tamilSubtitle="இன்று பயிற்சி செய்ய வேண்டிய சொற்றொடர்கள்"
      >
        <StatePlaceholder
          state={uiState}
          emptyMessage="No review cards due right now. You are all caught up!"
          tamilEmptyMessage="தற்போது மீள்பார்வை செய்ய வேண்டிய அட்டைகள் இல்லை!"
        >
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            {reviewCards.map((card, idx) => (
              <div
                key={idx}
                className="p-5 rounded-2xl bg-[#FFF0F3]/60 border border-pink-100 flex flex-col justify-between hover:border-[#FF5C8D]/40 transition-colors"
              >
                <div>
                  <span className="text-[10px] font-bold text-[#C72A63] uppercase tracking-wider bg-white px-2 py-0.5 rounded-full border border-pink-100">
                    {card.due}
                  </span>
                  <h4 className="text-lg font-extrabold text-[#4A0E2E] mt-3">
                    {card.german}
                  </h4>
                  <p className="text-xs text-[#7A3556] mt-1 font-medium">
                    {card.english}
                  </p>
                  <p className="text-xs text-[#FF5C8D] font-tamil font-semibold mt-0.5">
                    {card.tamil}
                  </p>
                </div>

                <button
                  type="button"
                  className="mt-4 w-full py-2 bg-white hover:bg-[#FFF0F3] text-[#4A0E2E] text-xs font-semibold rounded-xl border border-pink-200 transition-colors touch-target-min flex items-center justify-center gap-1.5"
                >
                  <RotateCcwIcon className="w-3.5 h-3.5 text-[#C72A63]" />
                  <span>Practice Card</span>
                </button>
              </div>
            ))}
          </div>

          <div className="mt-6 pt-4 border-t border-pink-100 flex justify-end">
            <button
              type="button"
              className="inline-flex items-center gap-2 px-5 py-2.5 bg-[#C72A63] hover:bg-[#A82253] text-white text-xs font-semibold rounded-xl shadow-xs transition-colors touch-target-min"
            >
              <SparklesIcon className="w-4 h-4" />
              <span>Start Review Session / பயிற்சியைத் தொடங்கு</span>
            </button>
          </div>
        </StatePlaceholder>
      </StitchedCard>
    </div>
  )
}
