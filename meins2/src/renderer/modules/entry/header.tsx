import React from 'react'
import { Entry } from '../../../generated/graphql'
import moment from 'moment'
import randomColor from 'randomcolor'

export function EntryHeader({ item }: { item: Entry }) {
  const formattedTs = moment(parseInt(item.timestamp)).format(
    'DD.MM.YYYY, HH:mm:SS',
  )
  const linkedCount = item.linked?.length || 0
  const storyName = item.story?.story_name
  const sagaName = item.story?.saga?.saga_name
  const backgroundColor = randomColor({ luminosity: 'light', seed: storyName })
  const color = randomColor({ luminosity: 'dark', seed: storyName })

  return (
    <div className="drag">
      <div className="header-1">
        <div>
          <div className="story-select">
            {storyName && sagaName && (
              <div
                className="story story-name"
                style={{ backgroundColor, color }}
              >
                <i className="fal fa-book " />
                <span>{`${sagaName}: ${storyName}`}</span>
              </div>
            )}
          </div>
        </div>
        <div>
          {linkedCount > 0 && (
            <span className="link-btn">linked: {linkedCount}</span>
          )}
        </div>
      </div>
      <div className="header">
        <div className="action-row">
          <div className="datetime">
            <a>
              <time className="ts">{formattedTs}</time>
            </a>
          </div>
          <div className="actions">
            <div className="items">
              <span className="cf-hashtag-select">
                <span>
                  <i className="fa fa-hashtag toggle " />
                </span>
              </span>
              <i className="fa fa-stopwatch toggle" />
              <i className="fa fa-comment toggle" />
              <i className="fa toggle far fa-arrow-alt-from-left" />
              <span className="delete-btn">
                <i className="fa fa-trash-alt toggle" />
              </span>
              <i className="fa fa-bug toggle" />
            </div>
            <i
              className={`fa toggle fa-star ${item.starred ? 'starred' : ''}`}
            />
            <i className="fa toggle fa-flag" />
          </div>
        </div>
      </div>
    </div>
  )
}
