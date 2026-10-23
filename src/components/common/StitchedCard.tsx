import React from 'react'

interface StitchedCardProps {
  children: React.ReactNode
  className?: string
  subtitle?: string
  title?: string
  tamilSubtitle?: string
}

/**
 * StitchedCard: The signature motif card with dashed border.
 * Rule: Rendered ONCE per screen for the primary hero or action area.
 */
export const StitchedCard: React.FC<StitchedCardProps> = ({
  children,
  className = '',
  subtitle,
  title,
  tamilSubtitle
}) => {
  return (
    <div
      className={`card-stitched p-6 sm:p-8 ${className}`}
      data-testid="stitched-card"
    >
      {(title || subtitle) && (
        <div className="mb-6">
          {title && (
            <h2 className="text-xl sm:text-2xl font-bold tracking-tight text-[#4A0E2E]">
              {title}
            </h2>
          )}
          {subtitle && (
            <p className="text-sm sm:text-base text-[#7A3556] mt-1">
              {subtitle}
            </p>
          )}
          {tamilSubtitle && (
            <p className="text-sm text-[#FF5C8D] font-medium font-tamil mt-0.5">
              {tamilSubtitle}
            </p>
          )}
        </div>
      )}
      {children}
    </div>
  )
}
