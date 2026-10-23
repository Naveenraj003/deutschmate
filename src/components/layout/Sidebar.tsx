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

export const Sidebar: React.FC = () => {
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
            label: 'Admin Console',
            tamil: 'நிர்வாக கன்சோல்',
            icon: ShieldAlertIcon
          }
        ]
      : [])
  ]

  return (
    <aside
      aria-label="Desktop Sidebar Navigation"
      className="hidden md:flex flex-col w-64 lg:w-72 bg-white/90 backdrop-blur-md border-r border-[#FF5C8D]/20 h-screen sticky top-0 p-6 shadow-sm"
    >
      {/* Brand Header */}
      <div className="flex items-center gap-3 mb-8 px-2">
        <div className="w-10 h-10 rounded-2xl bg-gradient-to-br from-[#FF5C8D] to-[#C72A63] flex items-center justify-center text-white shadow-sm font-black text-lg">
          DM
        </div>
        <div>
          <h1 className="text-xl font-bold tracking-tight text-[#4A0E2E] leading-tight">
            DeutschMate
          </h1>
          <p className="text-xs text-[#FF5C8D] font-medium font-tamil">
            ஜெர்மன் மொழியைக் கற்க
          </p>
        </div>
      </div>

      {/* Navigation Links */}
      <nav className="flex-1 space-y-1.5" aria-label="Main menu">
        {navItems.map((item) => {
          const Icon = item.icon
          return (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                `flex items-center gap-3.5 px-4 py-3 rounded-2xl font-medium text-sm transition-all touch-target-min ${
                  isActive
                    ? 'bg-[#FFF0F3] text-[#C72A63] font-bold shadow-xs'
                    : 'text-[#7A3556] hover:bg-[#FFF0F3]/60 hover:text-[#C72A63]'
                }`
              }
            >
              <Icon className="w-5 h-5 flex-shrink-0" />
              <div className="flex flex-col">
                <span>{item.label}</span>
                <span className="text-[11px] font-normal font-tamil text-[#FF5C8D]">
                  {item.tamil}
                </span>
              </div>
            </NavLink>
          )
        })}
      </nav>

      {/* User Info & Role Pill at bottom */}
      <div className="pt-4 border-t border-[#FF5C8D]/20 px-2">
        <div className="flex items-center justify-between">
          <div className="truncate">
            <p className="text-xs font-semibold text-[#4A0E2E] truncate">
              {user?.name || 'Guest'}
            </p>
            <p className="text-[11px] text-[#7A3556] capitalize">
              Role: <span className="font-semibold text-[#C72A63]">{user?.role}</span>
            </p>
          </div>
          <span
            className={`text-[10px] px-2 py-0.5 rounded-full font-semibold uppercase tracking-wider ${
              isAdmin
                ? 'bg-purple-100 text-purple-800 border border-purple-200'
                : 'bg-[#FFF0F3] text-[#C72A63] border border-[#FF5C8D]/30'
            }`}
          >
            {user?.role}
          </span>
        </div>
      </div>
    </aside>
  )
}
