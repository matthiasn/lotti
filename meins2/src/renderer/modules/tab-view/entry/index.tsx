import React from 'react'
import { EntryText } from './editor'
import { EntryHeader } from './header'
import { Entry } from '../../../../generated/graphql'
import { SpotifyView } from './spotify'
import { TaskView } from './task'
import { FooterView } from './footer'

export function EntryView({ item }: { item: Entry }) {
  const commentsCount = item.comments?.length

  return (
    <div className="entry-with-comments">
      <div draggable="true" className="entry">
        <EntryHeader item={item} />
        {!item.spotify && <EntryText />}
        <TaskView item={item} />
        <FooterView item={item} />
        <SpotifyView item={item} />
      </div>
      {!!commentsCount && (
        <div className="show-comments">
          <span>
            show {commentsCount} comment{commentsCount > 1 ? 's' : ''}
          </span>
        </div>
      )}
    </div>
  )
}
