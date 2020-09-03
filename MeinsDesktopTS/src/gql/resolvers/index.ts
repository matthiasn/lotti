import {tabSearch} from './tab-search'
import {Entry} from '../../generated/graphql'
import moment from 'moment'
import {Context} from '../../types'

export const resolvers = {
  Query: {
    tabSearch,
  },
  Entry: {
    created: (parent: Entry, _args: any, _ctx: Context) =>
      moment(parent.timestamp).format(),
  },
}
