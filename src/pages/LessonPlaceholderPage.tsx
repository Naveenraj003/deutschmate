import React from 'react'
import { useParams, Link } from 'react-router-dom'
import { StitchedCard } from '../components/common/StitchedCard'
import { ArrowLeftIcon, SparklesIcon } from '../components/icons'

export const LessonPlaceholderPage: React.FC = () => {
  const { lessonId } = useParams<{ lessonId: string }>()

  return (
    <div className="space-y-6">
      <div>
        <Link
          to="/learn"
          className="inline-flex items-center gap-2 text-xs font-semibold text-[#C72A63] hover:underline touch-target-min"
        >
          <ArrowLeftIcon className="w-4 h-4" />
          Back to All Lessons / பாடங்களுக்குத் திரும்புக
        </Link>
      </div>

      {/* The single stitched card for this screen */}
      <StitchedCard
        title={`Lesson ${lessonId?.toUpperCase() || ''}: In Development`}
        subtitle="This interactive lesson module is coming soon"
        tamilSubtitle="இந்த பாடம் விரைவில் வரவுள்ளது. தயாரிப்பில் உள்ளது."
      >
        <div className="py-8 text-center space-y-4">
          <div className="w-16 h-16 mx-auto rounded-3xl bg-[#FFF0F3] text-[#C72A63] flex items-center justify-center border border-[#FF5C8D]/20">
            <SparklesIcon className="w-8 h-8" />
          </div>

          <div>
            <h3 className="text-lg font-bold text-[#4A0E2E]">Lesson Coming Soon</h3>
            <p className="text-xs sm:text-sm text-[#7A3556] max-w-md mx-auto mt-1">
              The DeutschMate curriculum engine and Supabase data backend will power this interactive
              drill. For now, this placeholder verifies routing and navigation flow.
            </p>
            <p className="text-xs text-[#FF5C8D] font-tamil mt-2">
              ஊடாடும் பயிற்சி விரைவில் கிடைக்கப்பெறும்.
            </p>
          </div>

          <div className="pt-4">
            <Link
              to="/learn"
              className="inline-flex items-center gap-2 px-6 py-3 bg-[#C72A63] hover:bg-[#A82253] text-white text-sm font-semibold rounded-2xl transition-colors shadow-xs touch-target-min"
            >
              <ArrowLeftIcon className="w-4 h-4" />
              <span>Return to Dashboard</span>
            </Link>
          </div>
        </div>
      </StitchedCard>
    </div>
  )
}
