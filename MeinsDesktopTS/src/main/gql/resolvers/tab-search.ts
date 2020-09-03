import {Entry, TabSearchInput} from '../../../generated/graphql'
import {Context} from '../../types'
import log from 'loglevel'
import {ORMEntry} from '../../db/entities/entry'
import {FindManyOptions} from 'typeorm/find-options/FindManyOptions'
import {Like} from 'typeorm/index'
import moment from 'moment'

export async function tabSearch(
  _parent: {},
  {input}: {input: TabSearchInput},
  {db}: Context,
): Promise<Entry[]> {
  const {skip, query, take} = input
  const opts: FindManyOptions = {
    skip: skip || 0,
    take: take || 100,
    order: {timestamp: 'DESC'},
    where: {entryJson: Like(`%${input.query || ''}%`)},
  }

  const before = new Date().getTime()
  const entries = await db.getRepository(ORMEntry).find(opts)
  const after = new Date().getTime()
  log.info(`Query ${JSON.stringify(input)} took ${after - before}ms`)

  return entries.map((entry: ORMEntry) => {
    const parsed = JSON.parse(entry.entryJson)
    return parsed as Entry
  })
}
