import React from 'react'
import { Stats } from '../stats'
import { Briefing } from '../briefing'
import { TopBar } from '../top-bar'
import { InfiniteCalPicker } from '../infinite-calendar'
import { BusyStatus } from '../busy-status'
import { BigCalendar } from '../big-calendar'
import { TabSides, TabView } from '../tab-view'

export function MainScreen() {
  return (
    <div className={'flex-container'}>
      <div className={'grid'}>
        <div className={'wrapper col-3'}>
          <TopBar />
          <BusyStatus />
          <InfiniteCalPicker />
          <BigCalendar />
          <Briefing />
          <TabView side={TabSides.left} />
          <TabView side={TabSides.right} />
        </div>
      </div>
      <Stats />
    </div>
  )
}
