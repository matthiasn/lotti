// @ts-ignore
import edn from 'edn-to-js'
import * as fs from 'fs'
import log from 'loglevel'
import * as path from 'path'
import * as os from 'os'

const directoryPath = '/tmp/daily-logs'

export function listJrnFiles() {
  const fileRegex = /\d{4}-\d{2}-\d{2}.jrn/g
  return fs.readdirSync(directoryPath).filter((s) => s.match(fileRegex))
}

function entryProcessor(line: string) {
  const res = edn(line)
  log.info(res)
}

export function processFile(fileName: string) {
  const filePath = path.join(directoryPath, fileName)
  const lines: string[] = fs.readFileSync(filePath).toString().split(os.EOL)
  lines.forEach(entryProcessor)
}
