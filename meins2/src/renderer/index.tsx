import React from 'react'
import ReactDOM from 'react-dom'
import {ApolloProvider} from '@apollo/client'
import {apolloClient} from './gql/client'
import './index.css';
import {Stats} from './stats'

const client = apolloClient()

function App() {
  return (
    <ApolloProvider client={client}>
      <h1>Meins</h1>
      <Stats />
    </ApolloProvider>
  )
}

ReactDOM.render(<App />, document.getElementById('root'))
