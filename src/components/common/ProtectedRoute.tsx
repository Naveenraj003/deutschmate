import React from 'react'
import { Navigate } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import type { Role } from '../../types/auth'

interface ProtectedRouteProps {
  children: React.ReactNode
  requiredRole?: Role
}

/**
 * ProtectedRoute: Used for layout testing and placeholder route guards.
 * Real security and RLS is enforced downstream via Supabase.
 */
export const ProtectedRoute: React.FC<ProtectedRouteProps> = ({
  children,
  requiredRole
}) => {
  const { user } = useAuth()

  if (!user) {
    return <Navigate to="/login" replace />
  }

  if (requiredRole && user.role !== requiredRole) {
    // If learner attempts to view admin layout test route, redirect to /learn
    return <Navigate to="/learn" replace />
  }

  return <>{children}</>
}
