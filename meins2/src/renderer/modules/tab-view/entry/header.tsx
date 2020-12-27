import React from 'react'
import { Entry } from '../../../../generated/graphql'
import moment from 'moment'

export function EntryHeader({ item }: { item: Entry }) {
  const formattedTs = moment(parseInt(item.timestamp)).format(
    'DD.MM.YYYY, HH:mm:SS',
  )
  return (
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
          <i className="fa toggle fa-star" />
          <i className="fa toggle fa-flag" />
        </div>
      </div>
    </div>
  )
}
