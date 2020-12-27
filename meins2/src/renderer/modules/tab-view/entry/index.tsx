import React from 'react'
import { EditMenu } from './edit-menu'
import { EntryHeader } from './header'
import { Entry } from '../../../../generated/graphql'
import { SpotifyView } from './spotify'
import { TaskView } from './task'
import { FooterView } from './footer'

export function EntryView({ item }: { item: Entry }) {
  return (
    <div className="entry-with-comments">
      <div draggable="true" className="entry">
        <EntryHeader item={item} />
        {!item.spotify && <EditMenu />}
        <TaskView item={item} />
        <FooterView item={item} />
        <SpotifyView item={item} />
      </div>
      <div className="show-comments">
        <span>show 1 comment</span>
      </div>
    </div>
  )
}
