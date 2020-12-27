import React from 'react'
import { EditMenu } from './edit-menu'
import { EntryHeader } from './header'
import { Entry } from '../../../../generated/graphql'

export function EntryView({ item }: { item: Entry }) {
  return (
    <div className="entry-with-comments">
      <div draggable="true" className="entry">
        <EntryHeader item={item} />
        <EditMenu />
        <div className="task-details">
          <div className="overview">
            <span className="click">
              <i className="fas fa-check-circle" />
            </span>
            <span className="click closed">
              <i className="fas fa-times-circle" />
            </span>
            <span className="click">
              <i className="fas fa-cog" />
            </span>
          </div>
        </div>
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
      </div>
      <div className="show-comments">
        <span>show 1 comment</span>
      </div>
    </div>
  )
}
