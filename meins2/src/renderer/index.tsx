import React from 'react'
import ReactDOM from 'react-dom'
import { ApolloProvider, useQuery } from '@apollo/client'
import { apolloClient, NavScreen } from './gql/client'
import '../scss/meins.scss'
import '../../resources/fa5/fontawesome-all.min.css'
import 'lato-font/css/lato-font.css'
import 'normalize.css/normalize.css'
import 'typeface-montserrat/index.css'
import 'typeface-oswald/index.css'
import './ipc'
import { GET_STATE } from './gql/local-queries'
import { MainScreen } from './modules/main-screen'
import { SettingsScreen } from './modules/settings-screen'

const client = apolloClient()

function Nav() {
  const screen = useQuery(GET_STATE).data?.state?.screen
  return screen === NavScreen.HOME ? <MainScreen /> : <SettingsScreen />
}

function App() {
  return (
    <ApolloProvider client={client}>
      <Nav />
    </ApolloProvider>
  )
}

ReactDOM.render(<App />, document.getElementById('root'))
