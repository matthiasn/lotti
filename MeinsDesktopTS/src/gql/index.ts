import {ApolloServer} from 'apollo-server'
import {typeDefs} from './schema'

const resolvers = {
  Query: {
    tabSearch: () => [],
  },
}

export function startApollo(): ApolloServer {
  const server = new ApolloServer({
    typeDefs,
    resolvers,
  })

  server.listen({port: 4444}).then(({url}) => {
    console.log(`🚀 Server ready at ${url}`)
  })

  return server
}
