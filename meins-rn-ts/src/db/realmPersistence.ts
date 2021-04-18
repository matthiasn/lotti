import Realm from 'realm'

const EntrySchema = {
  name: 'Entry',
  properties: {
    _id: 'int',
    timestamp: 'int',
    text: 'string?',
    audioFile: 'string?',
  },
  primaryKey: '_id',
}

export const realm = new Realm({
  schema: [EntrySchema],
})

export type Entry = {
  timestamp: number
  text: string
  audioFile: string
}

export function addEntry(entry: Entry) {
  const { audioFile, text, timestamp } = entry
  realm.write(() => {
    realm.create('Entry', {
      _id: timestamp,
      text,
      audioFile,
      timestamp,
    })
  })
}
