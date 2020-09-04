import React from 'react'
import ReactDOM from 'react-dom'
import {ApolloProvider} from '@apollo/client'
import {Journal} from './journal'
import {apolloClient} from './gql/client'

const client = apolloClient()

function App() {
  return (
    <ApolloProvider client={client}>
      <h1>Meins Desktop on Electron</h1>
      <Journal />
    </ApolloProvider>
  )
}

ReactDOM.render(<App />, document.getElementById('root'))
