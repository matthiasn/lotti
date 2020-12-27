import React from 'react'
import InfiniteCalendar, {
  Calendar,
  DateSelectFunction,
  withDateSelection,
  withKeyboardSupport,
} from 'react-infinite-calendar'
import { useQuery } from '@apollo/client'
import moment from 'moment'
import { GET_STATE } from '../../gql/local-queries'
import { stateVar } from '../../gql/client'

export function InfiniteCalPicker() {
  const day = useQuery(GET_STATE).data?.state?.day
  const selected = moment(day).toDate()

  function onSelect(date: Date) {
    const day = moment(date).format('YYYY-MM-DD')
    stateVar({
      ...stateVar(),
      day,
    })
  }

  return (
    <div className="inf-cal">
      <div className="infinite-cal">
        <InfiniteCalendar
          width={400}
          height={600}
          selected={selected}
          onSelect={onSelect}
          Component={withDateSelection(withKeyboardSupport(Calendar))}
        />
        ,
      </div>
    </div>
  )
}
