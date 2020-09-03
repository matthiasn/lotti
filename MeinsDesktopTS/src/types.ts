import {Connection} from 'typeorm'

export type Context = {
  db: Connection
}
