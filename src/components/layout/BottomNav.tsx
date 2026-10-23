import React from 'react'
import { NavLink } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import {
  BarChart2Icon,
  BookOpenIcon,
  RotateCcwIcon,
  ShieldAlertIcon,
  UserIcon
} from '../icons'

export const BottomNav: React.FC = () => {
  const { user } = useAuth()
  const isAdmin = user?.role === 'admin'

  const navItems = [
    {
      to: '/learn',
      label: 'Learn',
      tamil: 'கற்க',
      icon: BookOpenIcon
    },
    {
      to: '/review',
      label: 'Review',
      tamil: 'மீள்பார்வை',
      icon: RotateCcwIcon
    },
    {
      to: '/progress',
      label: 'Progress',
      tamil: 'முன்னேற்றம்',
      icon: BarChart2Icon
    },
    {
      to: '/profile',
      label: 'Profile',
      tamil: 'சுயவிவரம்',
      icon: UserIcon
    },
    ...(isAdmin
      ? [
          {
            to: '/admin',
            label: 'Admin',
            tamil: 'நிர்வாகம்',
            icon: ShieldAlertIcon
          }
        ]
      : [])
  ]

  return (
    <nav
      aria-label="Mobile Bottom Navigation"
      className="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-white/95 backdrop-blur-md border-t border-[#FF5C8D]/20 px-2 py-1 shadow-lg pb-[env(safe-area-inset-bottom,0px)]"
    >
      <div className="flex items-center justify-around max-w-md mx-auto">
        {navItems.map((item) => {
          const Icon = item.icon
          return (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                `flex flex-col items-center justify-center py-1.5 px-2 rounded-2xl touch-target-min transition-all ${
                  isActive
                    ? 'text-[#C72A63] font-bold'
                    : 'text-[#7A3556] hover:text-[#C72A63]'
                }`
              }
            >
              {({ isActive }) => (
                <>
                  <div
                    className={`p-1 rounded-xl transition-all ${
                      isActive ? 'bg-[#FFF0F3] scale-110' : ''
                    }`}
                  >
                    <Icon className="w-5 h-5" />
                  </div>
                  <span className="text-[10px] tracking-tight mt-0.5 leading-none">
                    {item.label}
                  </span>
                  <span className="text-[9px] font-tamil text-[#FF5C8D] leading-none mt-0.5">
                    {item.tamil}
                  </span>
                </>
              )}
            </NavLink>
          )
        })}
      </div>
    </nav>
  )
}
