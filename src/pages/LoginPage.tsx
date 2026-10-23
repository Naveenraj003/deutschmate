import React, { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { StitchedCard } from '../components/common/StitchedCard'

export const LoginPage: React.FC = () => {
  const { login } = useAuth()
  const navigate = useNavigate()
  const [email, setEmail] = useState('kavitha@example.com')
  const [password, setPassword] = useState('password123')

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    login(email, 'learner', 'tamil')
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
            மீண்டும் வருக! உங்கள் கணக்கில் உள்நுழைக
          </p>
        </div>

        {/* The single stitched card for this screen */}
        <StitchedCard title="Sign In" subtitle="Enter your credentials to continue learning">
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-xs font-semibold text-[#4A0E2E] mb-1">
                Email Address / மின்னஞ்சல்
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                className="w-full px-4 py-3 rounded-xl border border-[#FF5C8D]/30 bg-white text-[#4A0E2E] text-sm focus:border-[#C72A63] touch-target-min"
                placeholder="you@example.com"
              />
            </div>

            <div>
              <div className="flex justify-between items-center mb-1">
                <label className="text-xs font-semibold text-[#4A0E2E]">
                  Password / கடவுச்சொல்
                </label>
                <Link
                  to="/reset-password"
                  className="text-xs text-[#C72A63] hover:underline font-medium"
                >
                  Forgot?
                </Link>
              </div>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                className="w-full px-4 py-3 rounded-xl border border-[#FF5C8D]/30 bg-white text-[#4A0E2E] text-sm focus:border-[#C72A63] touch-target-min"
              />
            </div>

            <button
              type="submit"
              className="w-full py-3.5 px-4 bg-[#C72A63] hover:bg-[#A82253] text-white font-semibold rounded-2xl transition-colors shadow-xs touch-target-min mt-2"
            >
              Sign In / உள்நுழைக
            </button>
          </form>

          <div className="mt-6 pt-4 border-t border-[#FF5C8D]/20 text-center text-xs text-[#7A3556]">
            Don't have an account?{' '}
            <Link to="/signup" className="text-[#C72A63] font-bold hover:underline">
              Create Account / கணக்கு தொடங்குக
            </Link>
          </div>
        </StitchedCard>
      </div>
    </div>
  )
}
