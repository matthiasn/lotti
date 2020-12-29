import React, { useState } from 'react'
import { EditorView } from '../editor'
import { EntryHeader } from './header'
import { Entry } from '../../../generated/graphql'
import { SpotifyView } from './spotify'
import { TaskView } from './task'
import { FooterView } from './footer'
import { TabSides } from '../tab-view'

export function EntryView({ item, side }: { item: Entry; side: TabSides }) {
  return (
    <div draggable="true" className="entry">
      <EntryHeader item={item} side={side} />
      {!item.spotify && <EditorView item={item} />}
      <TaskView item={item} />
      <FooterView item={item} />
      <SpotifyView item={item} />
    </div>
  )
}

export function EntryWithCommentsView({
  item,
  side,
}: {
  item: Entry
  side: TabSides
}) {
  const [showComments, setShowComments] = useState(false)

  const comments = item?.comments
  const commentsCount = comments?.length

  return (
    <div className="entry-with-comments">
      <EntryView item={item} side={side} />
      {!!commentsCount && (
        <div className={'comments'}>
          <div
            className="show-comments"
            onClick={() => setShowComments(!showComments)}
          >
            <span>
              show {commentsCount} comment{commentsCount > 1 ? 's' : ''}
            </span>
          </div>
          {showComments &&
            !!comments &&
            comments?.map((item: Entry) => (
              <EntryView
                item={item}
                side={side}
                key={`${side}-${item.timestamp}`}
              />
            ))}
        </div>
      )}
    </div>
  )
}
