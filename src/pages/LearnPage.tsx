import React from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { StitchedCard } from '../components/common/StitchedCard'
import { StatePlaceholder } from '../components/common/StatePlaceholder'
import { BookOpenIcon, SparklesIcon } from '../components/icons'

export const LearnPage: React.FC = () => {
  const { user, uiState } = useAuth()

  const lessons = [
    {
      id: 'a1-1',
      title: 'Greetings & Salutations',
      german: 'Begrüßungen und Verabschiedungen',
      tamil: 'வணக்கங்களும் விடைபெறுதலும்',
      duration: '5 mins'
    },
    {
      id: 'a1-2',
      title: 'Introducing Yourself',
      german: 'Sich vorstellen (Ich heiße...)',
      tamil: 'உங்களை அறிமுகப்படுத்துதல்',
      duration: '8 mins'
    },
    {
      id: 'a1-3',
      title: 'Numbers 1 to 20',
      german: 'Zahlen von 1 bis 20',
      tamil: 'எண்கள் 1 முதல் 20 வரை',
      duration: '10 mins'
    }
  ]

  return (
    <div className="space-y-6">
      {/* Top greeting banner */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-[#4A0E2E] tracking-tight">
            Guten Tag, {user?.name || 'Learner'}!
          </h1>
          <p className="text-xs sm:text-sm text-[#7A3556] mt-0.5">
            Teaching Language:{' '}
            <span className="font-bold text-[#C72A63] uppercase">
              {user?.teachingLanguage === 'tamil' ? 'தமிழ் (Tamil)' : 'English'}
            </span>
          </p>
        </div>
        <div className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-white rounded-2xl border border-[#FF5C8D]/20 shadow-xs self-start sm:self-auto">
          <span className="text-xs font-semibold text-[#4A0E2E]">🔥 Streak: 1 Day</span>
        </div>
      </div>

      {/* The single stitched card for this screen */}
      <StitchedCard
        title="Current Module: A1.1 Foundations"
        subtitle="Start your German journey with essential daily conversations"
        tamilSubtitle="அடிப்படை உரையாடல்களுடன் உங்கள் ஜெர்மன் மொழிப் பயணத்தைத் தொடங்குங்கள்"
      >
        <StatePlaceholder
          state={uiState}
          emptyMessage="No lessons assigned to this level yet."
          tamilEmptyMessage="இந்த நிலைக்கு இன்னும் பாடங்கள் ஒதுக்கப்படவில்லை."
        >
          <div className="space-y-3">
            {lessons.map((lesson, idx) => (
              <div
                key={lesson.id}
                className="p-4 rounded-2xl bg-[#FFF0F3]/50 border border-pink-100 flex flex-col sm:flex-row sm:items-center justify-between gap-3 hover:bg-[#FFF0F3] transition-colors"
              >
                <div className="flex items-start gap-3">
                  <div className="w-9 h-9 rounded-xl bg-white text-[#C72A63] font-bold text-sm flex items-center justify-center shadow-xs flex-shrink-0 mt-0.5">
                    {idx + 1}
                  </div>
                  <div>
                    <h3 className="text-sm sm:text-base font-bold text-[#4A0E2E]">
                      {lesson.title}
                    </h3>
                    <p className="text-xs text-[#7A3556] font-medium italic">
                      {lesson.german}
                    </p>
                    <p className="text-xs text-[#FF5C8D] font-tamil font-medium mt-0.5">
                      {lesson.tamil}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-2 self-end sm:self-center">
                  <span className="text-[11px] text-[#7A3556] bg-white px-2.5 py-1 rounded-full border border-pink-100">
                    {lesson.duration}
                  </span>
                  <Link
                    to={`/learn/${lesson.id}`}
                    className="inline-flex items-center gap-1.5 px-4 py-2 bg-[#C72A63] hover:bg-[#A82253] text-white text-xs font-semibold rounded-xl transition-colors shadow-2xs touch-target-min"
                  >
                    <span>Start</span>
                    <SparklesIcon className="w-3.5 h-3.5" />
                  </Link>
                </div>
              </div>
            ))}
          </div>
        </StatePlaceholder>
      </StitchedCard>

      {/* Secondary unstitched card for layout balance */}
      <div className="bg-white rounded-3xl p-6 border border-pink-100 shadow-xs">
        <h3 className="text-base font-bold text-[#4A0E2E] mb-1 flex items-center gap-2">
          <BookOpenIcon className="w-5 h-5 text-[#FF5C8D]" />
          <span>Grammar Tip of the Day</span>
        </h3>
        <p className="text-xs sm:text-sm text-[#7A3556] leading-relaxed">
          German nouns always start with a capital letter (e.g., <em>das Buch</em>, <em>der Tisch</em>).
          In Tamil, பெயர்ச்சொற்கள் பெரிய எழுத்தில் தொடங்கப்பட மாட்டாது, ஆனால் ஜெர்மனில் எப்போதும் முதலெழுத்து பெரியதாகவே இருக்கும்.
        </p>
      </div>
    </div>
  )
}
