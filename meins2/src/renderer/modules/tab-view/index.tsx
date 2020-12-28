import React from 'react'
import { EntryWithCommentsView } from './entry'
import { TabHeader } from './header'
import { Entry, useTabSeachQuery } from '../../../generated/graphql'

export enum TabSides {
  'left',
  'right',
}

export function TabView({ side, query }: { side: TabSides; query: string }) {
  const entries: Array<Entry> = useTabSeachQuery({
    variables: {
      n: 25,
      query,
    },
  }).data?.tab_search
  const sideName = TabSides[side]

  return (
    <div className={sideName}>
      <div className="tile-tabs">
        <TabHeader />
        <div className="journal">
          <div id={side.toString()} className="journal-entries">
            {entries?.map((item: Entry) => (
              <EntryWithCommentsView
                item={item}
                key={`${sideName}-${item.timestamp}`}
              />
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
