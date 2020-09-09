import {Entry, TabSearchInput} from '../../../generated/graphql'
import {Context} from '../../types'
import log from 'loglevel'
import {dbTabSearch, TabSearchParams} from '../../db/better-sqlite'

export async function tabSearch(
  _parent: {},
  {input}: {input: TabSearchInput},
  {db}: Context,
): Promise<Entry[]> {
  const {skip, query, take} = input

  const opts: TabSearchParams = {
    limit: take || 0,
    offset: skip || 0,
    search: `%${query || ''}%`,
  }

  const before = new Date().getTime()
  const entries = dbTabSearch(opts)
  const after = new Date().getTime()
  log.info(`Query ${JSON.stringify(input)} took ${after - before}ms`)

  return entries.map((entry) => {
    const parsed = JSON.parse(entry.entry_json)
    return parsed as Entry
  })
}
