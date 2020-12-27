import React from 'react'
import { useStatsQuery } from '../../../generated/graphql'
import * as fs from 'fs'

const appVersion = JSON.parse(fs.readFileSync('package.json').toString())
  .version

export function Stats() {
  const data = useStatsQuery({
    fetchPolicy: 'cache-and-network',
  }).data
  console.log(data)

  if (!data) {
    return null
  }

  return (
    <div className={'stats-string'}>
      <span className={'highlight'}>meins {appVersion}</span>
      {` beta | `}
      {`${data.entry_count} entries | `}
      {`${data.tag_count} tags | `}
      {`${data.mention_count} people | `}
      {`${data.hours_logged} hours | `}
      {`${data.open_tasks?.length} open tasks | `}
      {`${data.completed_count} done | `}
      {`${data.word_count} words | `}
      {`${data.active_threads} threads | `}
      <span className={'highlight'}>© Matthias Nehlsen</span>
    </div>
  )
}
