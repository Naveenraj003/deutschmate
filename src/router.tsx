import { createBrowserRouter } from 'react-router-dom'
import { AppLayout } from './components/layout/AppLayout'
import { ProtectedRoute } from './components/common/ProtectedRoute'
import { WelcomePage } from './pages/WelcomePage'
import { LoginPage } from './pages/LoginPage'
import { SignupPage } from './pages/SignupPage'
import { ResetPasswordPage } from './pages/ResetPasswordPage'
import { LearnPage } from './pages/LearnPage'
import { LessonPlaceholderPage } from './pages/LessonPlaceholderPage'
import { ReviewPage } from './pages/ReviewPage'
import { ProgressPage } from './pages/ProgressPage'
import { ProfilePage } from './pages/ProfilePage'
import { AdminPage } from './pages/AdminPage'
import { NotFoundPage } from './pages/NotFoundPage'

export const router = createBrowserRouter([
  {
    path: '/',
    element: <WelcomePage />
  },
  {
    path: '/login',
    element: <LoginPage />
  },
  {
    path: '/signup',
    element: <SignupPage />
  },
  {
    path: '/reset-password',
    element: <ResetPasswordPage />
  },
  {
    element: (
      <ProtectedRoute>
        <AppLayout />
      </ProtectedRoute>
    ),
    children: [
      {
        path: '/learn',
        element: <LearnPage />
      },
      {
        path: '/learn/:lessonId',
        element: <LessonPlaceholderPage />
      },
      {
        path: '/review',
        element: <ReviewPage />
      },
      {
        path: '/progress',
        element: <ProgressPage />
      },
      {
        path: '/profile',
        element: <ProfilePage />
      },
      {
        path: '/admin',
        element: (
          <ProtectedRoute requiredRole="admin">
            <AdminPage />
          </ProtectedRoute>
        )
      },
      {
        path: '*',
        element: <NotFoundPage />
      }
    ]
  }
])
