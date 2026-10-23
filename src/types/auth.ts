export type Role = 'learner' | 'admin'

export type TeachingLanguage = 'english' | 'tamil'

export interface LearnerUser {
  id: string
  name: string
  email: string
  role: Role
  teachingLanguage: TeachingLanguage
}

export type UIState = 'normal' | 'loading' | 'empty' | 'error'

export interface AuthContextType {
  user: LearnerUser | null
  login: (email?: string, role?: Role, lang?: TeachingLanguage) => void
  signup: (name: string, email: string, teachingLanguage: TeachingLanguage) => void
  logout: () => void
  toggleRole: () => void
  setTeachingLanguage: (lang: TeachingLanguage) => void
  // Dev-only UI state control for layout & placeholder inspection
  uiState: UIState
  setUIState: (state: UIState) => void
}
