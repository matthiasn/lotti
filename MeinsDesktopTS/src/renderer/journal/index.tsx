import {useQuery} from '@apollo/client'
import {TAB_SEARCH} from '../gql/queries'
import {Entry} from '../../generated/graphql'
import React from 'react'
import moment from 'moment'

export function Spotify({entry}: {entry: Entry}) {
  const spotify = entry?.spotify
  const image = spotify?.image

  if (!spotify) return null

  return (
    <div>
      {moment(parseInt(entry.timestamp)).fromNow()}
      {image && (
        <img
          className={'album-cover'}
          src={entry?.spotify?.image || ''}
          alt={spotify.name || ''}
        />
      )}
      )
    </div>
  )
}

export function Journal() {
  const entries: Array<Entry> = useQuery(TAB_SEARCH, {
    fetchPolicy: 'cache-and-network',
  }).data?.tabSearch

  return (
    <div>
      {entries &&
        entries.map((entry: Entry) => {
          return <Spotify entry={entry} />
        })}
    </div>
  )
}
