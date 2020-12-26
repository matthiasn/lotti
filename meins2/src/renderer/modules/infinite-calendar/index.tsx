import React from 'react'
import InifiniteCalendar, {
  Calendar,
  withDateSelection,
  withKeyboardSupport,
} from 'react-infinite-calendar'

export function InfiniteCalPicker() {
  var today = new Date()

  return (
    <div className="inf-cal">
      <div className="infinite-cal">
        <InifiniteCalendar
          width={400}
          height={600}
          selected={today}
          Component={withDateSelection(withKeyboardSupport(Calendar))}
        />
        ,
      </div>
    </div>
  )
}
