import log from 'loglevel'
import {listJrnFiles, processFile} from './files'

export function importEdn(): boolean {
  const files = listJrnFiles()
  log.info(files)
  files.forEach(processFile)

  return true
}
