import React from 'react'
import { EntryView } from './entry'
import { TabHeader } from './header'

export enum TabSides {
  'left',
  'right',
}

export function TabView({ side }: { side: TabSides }) {
  return (
    <div className={side.toString()}>
      <div className="tile-tabs">
        <TabHeader />
        <div className="journal">
          <div id={side.toString()} className="journal-entries">
            <EntryView />
          </div>
        </div>
      </div>
    </div>
  )
}
