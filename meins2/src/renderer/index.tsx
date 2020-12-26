import React from 'react'
import ReactDOM from 'react-dom'
import { ApolloProvider } from '@apollo/client'
import { apolloClient } from './gql/client'
import '../scss/meins.scss'
import { Stats } from './stats'
import {Briefing} from './briefing'

const client = apolloClient()

function App() {
  return (
    <ApolloProvider client={client}>
      <div className={'flex-container'}>
        <div className={'grid'}>
          <div className={'wrapper col-3'}>
            <Briefing />
          </div>
        </div>
        <Stats />
      </div>
    </ApolloProvider>
  )
}

ReactDOM.render(<App />, document.getElementById('root'))
