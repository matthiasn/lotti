import React from 'react'
import {useStatsQuery} from '../../generated/graphql'

export function Stats() {
  const data = useStatsQuery({
    fetchPolicy: 'cache-and-network',
  })
  console.log(data)

  return (
    <div className={'spotify-list'}>
    </div>
  )
}
