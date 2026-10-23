import React from 'react'
import { Link } from 'react-router-dom'
import { StitchedCard } from '../components/common/StitchedCard'
import { SparklesIcon } from '../components/icons'

export const WelcomePage: React.FC = () => {
  return (
    <div className="min-h-screen bg-[#FFF0F3] flex flex-col justify-center items-center px-4 py-8">
      <div className="w-full max-w-md">
        {/* Brand header */}
        <div className="text-center mb-6">
          <div className="w-16 h-16 mx-auto rounded-3xl bg-gradient-to-br from-[#FF5C8D] to-[#C72A63] flex items-center justify-center text-white shadow-md font-black text-2xl mb-3">
            DM
          </div>
          <h1 className="text-3xl font-extrabold text-[#4A0E2E] tracking-tight">
            DeutschMate
          </h1>
          <p className="text-sm font-semibold text-[#FF5C8D] font-tamil mt-1">
            ஜெர்மன் மொழியை எளிதாகக் கற்கலாம்
          </p>
          <p className="text-xs text-[#7A3556] mt-1">
            Learn German with English & Tamil explanations
          </p>
        </div>

        {/* The single stitched card for this screen */}
        <StitchedCard
          title="Willkommen! Welcome!"
          tamilSubtitle="வரவேற்கிறோம்! உங்கள் மொழிப்பயணத்தைத் தொடங்குங்கள்"
        >
          <p className="text-sm text-[#7A3556] leading-relaxed mb-6">
            Scaffold preview for the DeutschMate learning experience. Designed with blush warmth,
            gentle stitch borders, and tailored dual-language support for Tamil speakers.
          </p>

          <div className="space-y-3">
            <Link
              to="/signup"
              className="w-full flex items-center justify-center gap-2 py-3.5 px-4 bg-[#C72A63] hover:bg-[#A82253] text-white font-semibold rounded-2xl transition-colors shadow-xs touch-target-min"
            >
              <SparklesIcon className="w-5 h-5" />
              <span>Get Started / தொடங்குக</span>
            </Link>

            <Link
              to="/login"
              className="w-full flex items-center justify-center py-3.5 px-4 bg-white border border-[#FF5C8D]/40 text-[#4A0E2E] hover:bg-[#FFF0F3] font-semibold rounded-2xl transition-colors shadow-2xs touch-target-min"
            >
              Sign In / உள்நுழைக
            </Link>

            <Link
              to="/learn"
              className="w-full flex items-center justify-center text-xs text-[#7A3556] hover:text-[#C72A63] font-medium py-2 touch-target-min"
            >
              Skip directly to dashboard demo →
            </Link>
          </div>
        </StitchedCard>
      </div>
    </div>
  )
}
