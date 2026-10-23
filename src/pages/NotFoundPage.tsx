import React from 'react'
import { Link } from 'react-router-dom'
import { StitchedCard } from '../components/common/StitchedCard'
import { ArrowLeftIcon } from '../components/icons'

export const NotFoundPage: React.FC = () => {
  return (
    <div className="min-h-[70vh] flex flex-col justify-center items-center px-4">
      <div className="w-full max-w-md text-center">
        {/* The single stitched card for this screen */}
        <StitchedCard
          title="404 - Seite nicht gefunden"
          subtitle="The page you are looking for does not exist"
          tamilSubtitle="பக்கம் கிடைக்கவில்லை (404)"
        >
          <p className="text-xs sm:text-sm text-[#7A3556] mb-6">
            We couldn't find the requested page. Let's head back to the learning hub.
          </p>
          <Link
            to="/learn"
            className="inline-flex items-center gap-2 px-6 py-3 bg-[#C72A63] hover:bg-[#A82253] text-white text-xs font-semibold rounded-2xl transition-colors shadow-xs touch-target-min"
          >
            <ArrowLeftIcon className="w-4 h-4" />
            <span>Back to Learn Hub / முதன்மைப் பக்கம்</span>
          </Link>
        </StitchedCard>
      </div>
    </div>
  )
}
