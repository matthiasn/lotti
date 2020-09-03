// @ts-ignore
import edn from 'edn-to-js'
import * as fs from 'fs'
import log from 'loglevel'
import * as path from 'path'
import * as os from 'os'
import {dbConnection} from '../db'
import {ORMEntry} from '../db/entities/entry'
import {asyncForEach} from './util'

const directoryPath = '/tmp/daily-logs'
const fileRegex = /\d{4}-\d{2}-\d{2}.jrn/g

export function listJrnFiles() {
  return fs.readdirSync(directoryPath).filter((s) => s.match(fileRegex))
}

async function entryProcessor(line: string) {
  try {
    const db = await dbConnection()
    const parsed = edn(line)
    const entry = new ORMEntry()
    entry.entryJson = JSON.stringify(parsed)
    entry.timestamp = parsed.timestamp
    const dbRes = await db.getRepository(ORMEntry).insert(entry)
  } catch (e) {
    log.error('entryProcessor', e)
  }
}

export async function processFile(fileName: string) {
  const filePath = path.join(directoryPath, fileName)
  const lines: string[] = fs.readFileSync(filePath).toString().split(os.EOL)
  await asyncForEach(lines, entryProcessor)
}
