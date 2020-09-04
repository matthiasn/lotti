import {ApolloClient, HttpLink, InMemoryCache, makeVar} from '@apollo/client'

export enum Screen {
  HOME,
  SETTINGS,
}

export interface State {
  screen: Screen
}

export const stateVar = makeVar<State>(<State>{
  screen: 0,
})

const URI = 'http://localhost:4444/graphql'

export function apolloClient() {
  const link = new HttpLink({uri: URI})

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
