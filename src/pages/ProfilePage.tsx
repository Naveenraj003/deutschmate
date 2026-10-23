import React from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { StitchedCard } from '../components/common/StitchedCard'
import { UserIcon, ShieldAlertIcon } from '../components/icons'

export const ProfilePage: React.FC = () => {
  const { user, logout, toggleRole, setTeachingLanguage } = useAuth()
  const navigate = useNavigate()

  const handleLogout = () => {
    logout()
    navigate('/login')
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl sm:text-3xl font-extrabold text-[#4A0E2E] tracking-tight">
          Learner Profile & Settings
        </h1>
        <p className="text-xs sm:text-sm text-[#7A3556] mt-0.5">
          Manage your account preferences and learning configurations
        </p>
        <p className="text-xs text-[#FF5C8D] font-tamil">
          சுயவிவரம் மற்றும் அமைப்புகள்
        </p>
      </div>

      {/* The single stitched card for this screen */}
      <StitchedCard
        title="Personal Details"
        subtitle="Current active learner identity and settings"
        tamilSubtitle="தனிப்பட்ட விவரங்கள் மற்றும் அமைப்புகள்"
      >
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-pink-100">
          <div className="flex items-center gap-4">
            <div className="w-14 h-14 rounded-2xl bg-[#FFF0F3] text-[#C72A63] border border-[#FF5C8D]/30 flex items-center justify-center font-bold text-xl shadow-xs">
              <UserIcon className="w-7 h-7" />
            </div>
            <div>
              <h3 className="text-base font-bold text-[#4A0E2E]">{user?.name}</h3>
              <p className="text-xs text-[#7A3556]">{user?.email}</p>
              <div className="flex items-center gap-2 mt-1">
                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-[#FFF0F3] text-[#C72A63] border border-pink-200 uppercase">
                  Role: {user?.role}
                </span>
                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-pink-50 text-[#7A3556] border border-pink-200">
                  Lang: {user?.teachingLanguage}
                </span>
              </div>
            </div>
          </div>

          <button
            type="button"
            onClick={handleLogout}
            className="self-start sm:self-center px-4 py-2 border border-pink-200 hover:bg-[#FFF0F3] text-[#C72A63] text-xs font-semibold rounded-xl transition-colors touch-target-min"
          >
            Sign Out / வெளியேறுக
          </button>
        </div>

        {/* Teaching Language Toggle */}
        <div className="py-6 border-b border-pink-100">
          <label className="block text-xs font-bold text-[#4A0E2E] mb-2">
            Switch Preferred Explanation Language / கற்கும் மொழியை மாற்றுக:
          </label>
          <div className="flex gap-3">
            <button
              type="button"
              onClick={() => setTeachingLanguage('tamil')}
              className={`px-4 py-2.5 rounded-xl text-xs font-semibold border transition-all touch-target-min flex items-center gap-2 ${
                user?.teachingLanguage === 'tamil'
                  ? 'bg-[#C72A63] text-white border-[#C72A63] shadow-xs'
                  : 'bg-white text-[#4A0E2E] border-pink-200 hover:bg-[#FFF0F3]'
              }`}
            >
              <span>தமிழ் (Tamil)</span>
            </button>
            <button
              type="button"
              onClick={() => setTeachingLanguage('english')}
              className={`px-4 py-2.5 rounded-xl text-xs font-semibold border transition-all touch-target-min flex items-center gap-2 ${
                user?.teachingLanguage === 'english'
                  ? 'bg-[#C72A63] text-white border-[#C72A63] shadow-xs'
                  : 'bg-white text-[#4A0E2E] border-pink-200 hover:bg-[#FFF0F3]'
              }`}
            >
              <span>English</span>
            </button>
          </div>
        </div>

        {/* DEV-ONLY Role Toggle */}
        {import.meta.env.DEV && (
          <div className="pt-6">
            <div className="p-4 rounded-2xl bg-amber-50/80 border border-amber-200 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs font-bold text-amber-900 flex items-center gap-1.5">
                  <ShieldAlertIcon className="w-4 h-4 text-amber-700" />
                  <span>Dev Mock Role Tester (Hidden in Production)</span>
                </p>
                <p className="text-[11px] text-amber-800 mt-0.5">
                  Allows testing the responsive shell with and without the Admin navigation item.
                </p>
              </div>
              <button
                type="button"
                onClick={toggleRole}
                className="px-3 py-1.5 bg-amber-700 hover:bg-amber-800 text-white text-xs font-semibold rounded-xl transition-colors shadow-2xs touch-target-min self-start sm:self-center"
              >
                Switch to {user?.role === 'admin' ? 'Learner' : 'Admin'}
              </button>
            </div>
          </div>
        )}
      </StitchedCard>
    </div>
  )
}
