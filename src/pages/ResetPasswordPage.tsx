import React, { useState } from 'react'
import { Link } from 'react-router-dom'
import { StitchedCard } from '../components/common/StitchedCard'
import { ArrowLeftIcon, CheckIcon } from '../components/icons'

export const ResetPasswordPage: React.FC = () => {
  const [email, setEmail] = useState('')
  const [submitted, setSubmitted] = useState(false)

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setSubmitted(true)
  }

  return (
    <div className="min-h-screen bg-[#FFF0F3] flex flex-col justify-center items-center px-4 py-8">
      <div className="w-full max-w-md">
        <div className="text-center mb-6">
          <Link to="/" className="inline-block">
            <h1 className="text-2xl font-black text-[#4A0E2E]">DeutschMate</h1>
          </Link>
          <p className="text-xs text-[#7A3556] mt-1 font-tamil">
            கடவுச்சொல் மீட்பு
          </p>
        </div>

        {/* The single stitched card for this screen */}
        <StitchedCard
          title="Reset Password"
          subtitle="We will send you a link to reset your account password"
          tamilSubtitle="உங்கள் கடவுச்சொல்லை மீட்டமைக்க இணைப்பு அனுப்பப்படும்"
        >
          {submitted ? (
            <div className="text-center py-4 space-y-4">
              <div className="w-12 h-12 mx-auto rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center">
                <CheckIcon className="w-6 h-6" />
              </div>
              <p className="text-sm font-semibold text-[#4A0E2E]">
                Reset link sent to <span className="text-[#C72A63]">{email}</span>
              </p>
              <p className="text-xs text-[#7A3556] font-tamil">
                உங்கள் மின்னஞ்சலைச் சரிபார்க்கவும்.
              </p>
              <Link
                to="/login"
                className="inline-flex items-center gap-2 mt-4 text-xs font-bold text-[#C72A63] hover:underline"
              >
                <ArrowLeftIcon className="w-4 h-4" />
                Back to Sign In / உள்நுழைவுக்குத் திரும்புக
              </Link>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-[#4A0E2E] mb-1">
                  Registered Email / பதிவுசெய்த மின்னஞ்சல்
                </label>
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  placeholder="name@example.com"
                  className="w-full px-4 py-3 rounded-xl border border-[#FF5C8D]/30 bg-white text-[#4A0E2E] text-sm focus:border-[#C72A63] touch-target-min"
                />
              </div>

              <button
                type="submit"
                className="w-full py-3.5 px-4 bg-[#C72A63] hover:bg-[#A82253] text-white font-semibold rounded-2xl transition-colors shadow-xs touch-target-min"
              >
                Send Reset Link / இணைப்பு அனுப்புக
              </button>

              <div className="pt-2 text-center">
                <Link
                  to="/login"
                  className="inline-flex items-center gap-1.5 text-xs text-[#7A3556] hover:text-[#C72A63] font-medium"
                >
                  <ArrowLeftIcon className="w-3.5 h-3.5" />
                  Cancel and return to Sign In
                </Link>
              </div>
            </form>
          )}
        </StitchedCard>
      </div>
    </div>
  )
}
