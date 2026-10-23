import React, { createContext, useContext, useState } from 'react'
import type { AuthContextType, LearnerUser, Role, TeachingLanguage, UIState } from '../types/auth'

const AuthContext = createContext<AuthContextType | undefined>(undefined)

const DEFAULT_USER: LearnerUser = {
  id: 'learner-1',
  name: 'Kavitha S.',
  email: 'kavitha@example.com',
  role: 'learner',
  teachingLanguage: 'tamil'
}

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<LearnerUser | null>(DEFAULT_USER)
  const [uiState, setUIState] = useState<UIState>('normal')

  const login = (
    email = 'kavitha@example.com',
    role: Role = 'learner',
    lang: TeachingLanguage = 'tamil'
  ) => {
    setUser({
      id: 'learner-' + Math.floor(Math.random() * 1000),
      name: email.split('@')[0] || 'Learner',
      email,
      role,
      teachingLanguage: lang
    })
  }

  const signup = (name: string, email: string, teachingLanguage: TeachingLanguage) => {
    setUser({
      id: 'learner-' + Math.floor(Math.random() * 1000),
      name: name.trim() || 'New Learner',
      email: email.trim() || 'new@deutschmate.app',
      role: 'learner',
      teachingLanguage
    })
  }

  const logout = () => {
    setUser(null)
  }

  const toggleRole = () => {
    setUser((prev) => {
      if (!prev) return null
      return {
        ...prev,
        role: prev.role === 'admin' ? 'learner' : 'admin'
      }
    })
  }

  const setTeachingLanguage = (lang: TeachingLanguage) => {
    setUser((prev) => {
      if (!prev) return null
      return {
        ...prev,
        teachingLanguage: lang
      }
    })
  }

  return (
    <AuthContext.Provider
      value={{
        user,
        login,
        signup,
        logout,
        toggleRole,
        setTeachingLanguage,
        uiState,
        setUIState
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}
