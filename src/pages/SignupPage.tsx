import React, { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { StitchedCard } from '../components/common/StitchedCard'
import type { TeachingLanguage } from '../types/auth'
import { CheckIcon } from '../components/icons'

export const SignupPage: React.FC = () => {
  const { signup } = useAuth()
  const navigate = useNavigate()

  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [teachingLanguage, setLanguage] = useState<TeachingLanguage>('tamil')

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    signup(name || 'New Learner', email || 'learner@deutschmate.app', teachingLanguage)
    navigate('/learn')
  }

  return (
    <div className="min-h-screen bg-[#FFF0F3] flex flex-col justify-center items-center px-4 py-8">
      <div className="w-full max-w-md">
        <div className="text-center mb-6">
          <Link to="/" className="inline-block">
            <h1 className="text-2xl font-black text-[#4A0E2E]">DeutschMate</h1>
          </Link>
          <p className="text-xs text-[#7A3556] mt-1 font-tamil">
            புதிய கணக்கை உருவாக்கி ஜெர்மன் கற்கத் தொடங்குங்கள்
          </p>
        </div>

        {/* The single stitched card for this screen */}
        <StitchedCard
          title="Create Learner Account"
          subtitle="Choose your preferred teaching explanation language"
          tamilSubtitle="விளக்க மொழியைத் தேர்வு செய்யவும்"
        >
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-xs font-semibold text-[#4A0E2E] mb-1">
                Your Name / உங்கள் பெயர்
              </label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                required
                placeholder="e.g. Anand"
                className="w-full px-4 py-3 rounded-xl border border-[#FF5C8D]/30 bg-white text-[#4A0E2E] text-sm focus:border-[#C72A63] touch-target-min"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-[#4A0E2E] mb-1">
                Email Address / மின்னஞ்சல்
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                placeholder="anand@example.com"
                className="w-full px-4 py-3 rounded-xl border border-[#FF5C8D]/30 bg-white text-[#4A0E2E] text-sm focus:border-[#C72A63] touch-target-min"
              />
            </div>

            {/* Teaching Language Choice - Stored in App State */}
            <div className="pt-1">
              <label className="block text-xs font-semibold text-[#4A0E2E] mb-2">
                Teaching Language / கற்கும் முறை:
              </label>
              <div className="grid grid-cols-2 gap-3">
                <button
                  type="button"
                  onClick={() => setLanguage('tamil')}
                  className={`p-3.5 rounded-2xl border text-left transition-all relative touch-target-min ${
                    teachingLanguage === 'tamil'
                      ? 'border-[#C72A63] bg-[#FFF0F3] shadow-xs'
                      : 'border-pink-200 bg-white hover:border-[#FF5C8D]'
                  }`}
                >
                  {teachingLanguage === 'tamil' && (
                    <div className="absolute top-2.5 right-2.5 text-[#C72A63]">
                      <CheckIcon className="w-4 h-4" />
                    </div>
                  )}
                  <p className="font-bold text-sm text-[#4A0E2E] font-tamil">தமிழ் (Tamil)</p>
                  <p className="text-[11px] text-[#7A3556] mt-0.5">German via Tamil</p>
                </button>

                <button
                  type="button"
                  onClick={() => setLanguage('english')}
                  className={`p-3.5 rounded-2xl border text-left transition-all relative touch-target-min ${
                    teachingLanguage === 'english'
                      ? 'border-[#C72A63] bg-[#FFF0F3] shadow-xs'
                      : 'border-pink-200 bg-white hover:border-[#FF5C8D]'
                  }`}
                >
                  {teachingLanguage === 'english' && (
                    <div className="absolute top-2.5 right-2.5 text-[#C72A63]">
                      <CheckIcon className="w-4 h-4" />
                    </div>
                  )}
                  <p className="font-bold text-sm text-[#4A0E2E]">English</p>
                  <p className="text-[11px] text-[#7A3556] mt-0.5">German via English</p>
                </button>
              </div>
            </div>

            <button
              type="submit"
              className="w-full py-3.5 px-4 bg-[#C72A63] hover:bg-[#A82253] text-white font-semibold rounded-2xl transition-colors shadow-xs touch-target-min mt-4"
            >
              Sign Up / கணக்கு தொடங்கு
            </button>
          </form>

          <div className="mt-6 pt-4 border-t border-[#FF5C8D]/20 text-center text-xs text-[#7A3556]">
            Already registered?{' '}
            <Link to="/login" className="text-[#C72A63] font-bold hover:underline">
              Sign In / உள்நுழைக
            </Link>
          </div>
        </StitchedCard>
      </div>
    </div>
  )
}
