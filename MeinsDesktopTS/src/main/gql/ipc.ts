import {ipcMain} from 'electron'
import {createSchemaLink, createIpcExecutor} from 'graphql-transport-electron'
const {makeExecutableSchema} = require('apollo-server')

import {typeDefs} from './schema'
import {resolvers} from './resolvers'
import log from 'loglevel'

const schema = makeExecutableSchema({
  typeDefs,
  resolvers,
})

export function startGqlIpc(): void {
  const link = createSchemaLink({schema})
  createIpcExecutor({link, ipc: ipcMain})
  log.info('Apollo listening on IPC')
}
