import {
  ApolloClient,
  ApolloLink,
  HttpLink,
  InMemoryCache,
  makeVar,
} from '@apollo/client'
import { onError } from '@apollo/client/link/error'
import moment from 'moment'

const DEBUG = true

export enum Screen {
  HOME,
  SETTINGS,
}

export interface State {
  screen: Screen
  day: string
}

export const stateVar = makeVar<State>(<State>{
  screen: 0,
  day: moment().subtract(1, 'day').format('YYYY-MM-DD'),
})

const URI = 'http://localhost:8766/graphql'

export function apolloClient() {
  const errorLink = onError(({ graphQLErrors, networkError }) => {
    if (graphQLErrors)
      graphQLErrors.map(({ message, locations, path }) =>
        console.log(
          `[GraphQL error]: Message: ${message}, Location: ${locations}, Path: ${path}`,
        ),
      )
    if (networkError) console.log(`[Network error]: ${networkError}`)
  })

  const httpLink = new HttpLink({
    uri: URI,
    fetch: (...pl) => {
      const [_, options] = pl
      if (DEBUG) {
        const body = JSON.parse(options.body.toString())
        console.log(
          `📡 ${body.operationName || ''}\n${body.query}`,
          body.variables,
        )
      }
      const res = fetch(...pl)
      if (DEBUG) {
        res.then((v) => console.log(v))
      }
      return res
    },
  })

  const link = ApolloLink.from([errorLink, httpLink])

  const cache: InMemoryCache = new InMemoryCache({
    typePolicies: {
      Query: {
        fields: {
          state: {
            read() {
              return stateVar()
            },
          },
        },
      },
    },
  })

  return new ApolloClient({
    cache,
    link,
  })
}
