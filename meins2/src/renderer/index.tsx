import React from 'react'
import ReactDOM from 'react-dom'
import { ApolloProvider } from '@apollo/client'
import { apolloClient } from './gql/client'
import '../scss/meins.scss'
import '../../resources/fa5/fontawesome-all.min.css'
import 'lato-font/css/lato-font.css'
import 'normalize.css/normalize.css'
import 'typeface-montserrat/index.css'
import 'typeface-oswald/index.css'
import { Stats } from './modules/stats'
import { Briefing } from './briefing'
import { TopBar } from './modules/top-bar'
import { InfiniteCalPicker } from './modules/infinite-calendar'
import { BusyStatus } from './modules/busy-status'
import { BigCalendar } from './modules/big-calendar'
import { TabSides, TabView } from './modules/tab-view'

const client = apolloClient()

function App() {
  return (
    <ApolloProvider client={client}>
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
    </ApolloProvider>
  )
}

ReactDOM.render(<App />, document.getElementById('root'))
