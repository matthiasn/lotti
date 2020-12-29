import React from 'react'
import { Entry } from '../../../generated/graphql'
import moment, { duration } from 'moment'

export function FooterView({ item }: { item: Entry }) {
  const tags = item.tags
  const loggedSeconds = item.comments?.reduce(
    (acc, entry) => acc + entry.completed_time,
    0,
  )
  const loggedTime = moment
    .utc(duration(loggedSeconds, 's').asMilliseconds())
    .format('HH:mm:SS')

  return (
    <div className="entry-footer">
      {loggedSeconds > 0 && (
        <div className="pomodoro">
          <div className="dur">{loggedTime}</div>
        </div>
      )}
      <div className="hashtags">
        {tags?.map((tag) => (
          <span className="hashtag" key={`${item.timestamp}-${tag}`}>
            {tag}
          </span>
        ))}
      </div>
      <div className="word-count" />
    </div>
  )
}
