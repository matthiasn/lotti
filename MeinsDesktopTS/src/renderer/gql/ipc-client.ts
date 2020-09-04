import {ApolloClient} from '@apollo/client'
import {InMemoryCache} from '@apollo/client'
import {ipcRenderer} from 'electron'
import {createIpcLink} from '@matthiasn/graphql-transport-electron'

const link = createIpcLink({
  ipc: ipcRenderer,
  contextSerializer: () => {},
})

// not working yet
export const ipcClient = new ApolloClient({
  cache: new InMemoryCache(),
  link,
})
