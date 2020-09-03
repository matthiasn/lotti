import {ApolloServer} from 'apollo-server'
import {typeDefs} from './schema'
import {resolvers} from './resolvers'
import {Context} from '../types'
import {dbConnection} from '../db'

async function context(_payload: any): Promise<Context> {
  return <Context>{
    db: await dbConnection(),
  }
}

export function startApollo(): ApolloServer {
  const server = new ApolloServer({
    context,
    typeDefs,
    resolvers,
  })

  server.listen({port: 4444}).then(({url}) => {
    console.log(`🚀 Server ready at ${url}`)
  })

  return server
}
