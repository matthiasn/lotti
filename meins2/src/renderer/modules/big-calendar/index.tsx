import React from 'react'
import { Calendar, momentLocalizer } from 'react-big-calendar'
import moment from 'moment'
import randomColor from 'randomcolor'
import { LoggedCalItem, useLoggedTimeQuery } from '../../../generated/graphql'
import { useQuery } from '@apollo/client'
import { GET_STATE } from '../../gql/local-queries'

const localizer = momentLocalizer(moment)

function eventMapper(item: LoggedCalItem) {
  const storyName = item.story?.story_name
  const title = storyName ? `${storyName}: ${item.text}` : item.text
  const bgColor = randomColor({ luminosity: 'light', seed: storyName })
  const color = randomColor({ luminosity: 'dark', seed: storyName })
  const start = new Date(parseInt(item.timestamp))
  const end = new Date(parseInt(item.timestamp) + item.completed * 1000)

  return {
    title,
    ts: item.timestamp,
    bgColor,
    color,
    start,
    end,
  }
}

function eventPropGetter(event: any) {
  return {
    style: {
      backgroundColor: event?.bgColor,
      color: event?.color,
    },
  }
}

export function BigCalendar() {
  const day = useQuery(GET_STATE).data?.state?.day
  const events = useLoggedTimeQuery({
    variables: {
      day,
    },
  }).data?.logged_time?.by_ts_cal?.map(eventMapper)

  if (!events) {
    return null
  }

  return (
    <div className="cal">
      <div className="cal-container">
        <div className="big-calendar">
          <Calendar
            localizer={localizer}
            defaultDate={moment(day).toDate()}
            events={events}
            defaultView="day"
            eventPropGetter={eventPropGetter}
            toolbar={false}
            showMultiDayTimes={true}
            startAccessor="start"
            endAccessor="end"
          />
        </div>
      </div>
    </div>
  )
}
