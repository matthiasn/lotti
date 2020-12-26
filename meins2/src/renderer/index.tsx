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
import { Stats } from './stats'
import { Briefing } from './briefing'
import {TopBar} from './modules/top-bar'

const client = apolloClient()

function App() {
  return (
    <ApolloProvider client={client}>
      <div className={'flex-container'}>
        <div className={'grid'}>
          <div className={'wrapper col-3'}>
            <TopBar />
            <Briefing />
          </div>
        </div>
        <Stats />
      </div>
    </ApolloProvider>
  )
}

ReactDOM.render(<App />, document.getElementById('root'))
