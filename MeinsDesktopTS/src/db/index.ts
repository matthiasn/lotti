import {Connection, ConnectionOptions, createConnection} from 'typeorm'
import {Entry} from './entities/entry'

const DB_PATH = '/tmp/meinsTS/db'
const options: ConnectionOptions = {
  type: 'sqlite',
  database: DB_PATH,
  entities: [Entry],
  synchronize: true,
  logging: ['warn', 'error'],
}
const connection = createConnection(options)

export async function dbConnection(): Promise<Connection> {
  return connection
}
