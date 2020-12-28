import React, { useState } from 'react'
import { EditorView } from '../../editor'
import { EntryHeader } from './header'
import { Entry } from '../../../../generated/graphql'
import { SpotifyView } from './spotify'
import { TaskView } from './task'
import { FooterView } from './footer'

export function EntryView({ item }: { item: Entry }) {
  return (
    <div draggable="true" className="entry">
      <EntryHeader item={item} />
      {!item.spotify && <EditorView item={item} />}
      <TaskView item={item} />
      <FooterView item={item} />
      <SpotifyView item={item} />
    </div>
  )
}

export function EntryWithCommentsView({ item }: { item: Entry }) {
  const [showComments, setShowComments] = useState(false)

  const comments = item?.comments
  const commentsCount = comments?.length

  return (
    <div className="entry-with-comments">
      <EntryView item={item} />
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
            comments?.map((item: Entry) => <EntryView item={item} />)}
        </div>
      )}
    </div>
  )
}
