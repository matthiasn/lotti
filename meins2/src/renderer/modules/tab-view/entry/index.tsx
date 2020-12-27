import React from 'react'
import { EditMenu } from './edit-menu'
import { EntryHeader } from './header'
import { Entry } from '../../../../generated/graphql'
import { SpotifyView } from './spotify'
import { TaskView } from './task'

export function EntryView({ item }: { item: Entry }) {
  return (
    <div className="entry-with-comments">
      <div draggable="true" className="entry">
        <EntryHeader item={item} />
        {!item.spotify && <EditMenu />}
        <TaskView item={item} />
        <div className="entry-footer">
          <div className="pomodoro">
            <div className="dur">00:30:00</div>
          </div>
          <div className="hashtags">
            <span className="hashtag">#task</span>
            <span className="hashtag">#photo</span>
            <span className="hashtag">#screenshot</span>
            <span className="hashtag">#PR</span>
          </div>
          <div className="word-count" />
        </div>
        <SpotifyView item={item} />
      </div>
      <div className="show-comments">
        <span>show 1 comment</span>
      </div>
    </div>
  )
}
