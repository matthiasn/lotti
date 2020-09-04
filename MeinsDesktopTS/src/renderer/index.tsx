import React from 'react'
import ReactDOM from 'react-dom'
import {ApolloProvider} from '@apollo/client'
import {Journal} from './journal'
import {apolloClient} from './gql/client'

const client = apolloClient()

function App() {
  return (
    <ApolloProvider client={client}>
      <h1>Listened recently</h1>
      <Journal />
    </ApolloProvider>
  )
}

ReactDOM.render(<App />, document.getElementById('root'))
