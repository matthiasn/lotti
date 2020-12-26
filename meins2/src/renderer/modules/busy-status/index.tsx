import React from 'react'

export function BusyStatus() {
  const status = 'green'

  return <div className={`busy-status rec-indicator ${status}`} />
}
