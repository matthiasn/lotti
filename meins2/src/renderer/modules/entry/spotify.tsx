import React from 'react'
import { Artist, Entry } from '../../../generated/graphql'

export function SpotifyView({ item }: { item: Entry }) {
  const spotify = item.spotify

  if (!spotify) {
    return null
  }

  const artists = spotify?.artists
    ?.map((artist: Artist) => artist.name)
    .join(', ')

  return (
    <div className="spotify">
      <div className="title">{spotify.name}</div>
      <div className="artist">{artists}</div>
      <img src={spotify.image} draggable="false" alt={spotify.name} />
    </div>
  )
}
