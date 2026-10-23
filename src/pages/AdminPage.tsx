import React from 'react'
import { StitchedCard } from '../components/common/StitchedCard'
import { ShieldAlertIcon } from '../components/icons'

export const AdminPage: React.FC = () => {
  return (
    <div className="space-y-6">
      <div>
        <div className="inline-flex items-center gap-1.5 px-3 py-1 bg-purple-100 text-purple-900 border border-purple-200 rounded-full text-xs font-bold mb-2">
          <ShieldAlertIcon className="w-3.5 h-3.5" />
          <span>Admin Layout Preview</span>
        </div>
        <h1 className="text-2xl sm:text-3xl font-extrabold text-[#4A0E2E] tracking-tight">
          Curriculum & Content Management
        </h1>
        <p className="text-xs sm:text-sm text-[#7A3556] mt-0.5">
          Mock administration dashboard for lesson authors and administrators
        </p>
        <p className="text-xs text-[#FF5C8D] font-tamil">
          நிர்வாக மேலாண்மை கன்சோல்
        </p>
      </div>

      {/* The single stitched card for this screen */}
      <StitchedCard
        title="Curriculum Overview (Mock Controls)"
        subtitle="Layout test view — real authorization is strictly enforced downstream via Supabase RLS"
        tamilSubtitle="பாடத்திட்ட மேலாண்மை மற்றும் சரிபார்ப்பு"
      >
        <div className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div className="p-4 rounded-2xl bg-[#FFF0F3]/60 border border-pink-100">
              <span className="text-xs font-semibold text-[#7A3556]">Total Lessons</span>
              <p className="text-2xl font-black text-[#C72A63] mt-1">24</p>
              <p className="text-[11px] text-[#7A3556] mt-0.5">Across A1, A2 modules</p>
            </div>

            <div className="p-4 rounded-2xl bg-[#FFF0F3]/60 border border-pink-100">
              <span className="text-xs font-semibold text-[#7A3556]">Tamil Translations</span>
              <p className="text-2xl font-black text-[#C72A63] mt-1">100%</p>
              <p className="text-[11px] text-[#7A3556] mt-0.5">All vetted by native speakers</p>
            </div>

            <div className="p-4 rounded-2xl bg-[#FFF0F3]/60 border border-pink-100">
              <span className="text-xs font-semibold text-[#7A3556]">Active Learners</span>
              <p className="text-2xl font-black text-[#C72A63] mt-1">1,240</p>
              <p className="text-[11px] text-[#7A3556] mt-0.5">Mock cohort</p>
            </div>
          </div>

          <div className="p-4 rounded-2xl bg-amber-50/70 border border-amber-200 text-xs text-amber-900 leading-relaxed">
            <strong>Architecture Note:</strong> This route is included in the scaffold to test responsive
            sidebar and mobile bottom-bar items for admin roles. Production security will rely on Supabase
            authentication and row-level security (RLS) policies.
          </div>
        </div>
      </StitchedCard>
    </div>
  )
}
