import React from 'react'
import { EntryWithCommentsView } from './entry'
import { TabHeader } from './header'
import { Entry, useTabSeachQuery } from '../../../generated/graphql'
import { useQuery } from '@apollo/client'
import { GET_STATE } from '../../gql/local-queries'

export enum TabSides {
  'left',
  'right',
}

export function TabView({ side }: { side: TabSides }) {
  const sideName = TabSides[side]
  const query = useQuery(GET_STATE).data?.state?.[sideName]

  const entries: Array<Entry> = useTabSeachQuery({
    variables: {
      n: 25,
      query,
    },
  }).data?.tab_search

  return (
    <div className={sideName}>
      <div className="tile-tabs">
        <TabHeader />
        <div className="journal">
          <div id={sideName} className="journal-entries">
            {entries?.map((item: Entry) => (
              <EntryWithCommentsView
                item={item}
                sideName={sideName}
                key={`${sideName}-${item.timestamp}`}
              />
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
