import {Entry, TabSearchInput} from '../../generated/graphql'
import {Context} from '../../types'
import log from 'loglevel'
import {ORMEntry} from '../../db/entities/entry'
import {FindManyOptions} from 'typeorm/find-options/FindManyOptions'

export async function tabSearch(
  _parent: {},
  {input}: {input: TabSearchInput},
  {db}: Context,
): Promise<Entry[]> {
  const opts: FindManyOptions = {
    skip: input.skip || 0,
    take: input.take || 100,
    order: {timestamp: 'DESC'},
  }

  const entries = await db.getRepository(ORMEntry).find(opts)

  return entries.map((entry: ORMEntry) => {
    const parsed = JSON.parse(entry.entryJson)
    return parsed as Entry
  })
}
