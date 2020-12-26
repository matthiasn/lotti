import React from 'react'
import {useStatsQuery} from '../../generated/graphql'
import * as fs from 'fs'

const appVersion = JSON.parse(fs.readFileSync('package.json').toString()).version

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
      {`meins `}<span className={'highlight'}>{appVersion}</span>{` beta | `}
      {`${data.entry_count} entries | `}
      {`${data.tag_count} tags | `}
      {`${data.mention_count} people | `}
      {`${data.completed_count} done | `}
      {`${data.word_count} words | `}
      {`${data.active_threads} threads | `}
      © Matthias Nehlsen
    </div>
  )
}
