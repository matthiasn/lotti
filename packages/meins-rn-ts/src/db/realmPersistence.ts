import Realm from 'realm'

const EntrySchema = {
  name: 'Entry',
  properties: {
    _id: 'int',
    timestamp: 'int',
    text: 'string?',
    uri: 'string?',
  },
  primaryKey: '_id',
}

export const realm = new Realm({
  schema: [EntrySchema],
})

export type Entry = {
  timestamp: number
  text: string
  uri: string
}

export function addEntry(entry: Entry) {
  const { uri, text, timestamp } = entry
  realm.write(() => {
    realm.create('Entry', {
      _id: timestamp,
      text,
      uri,
      timestamp,
    })

    const entries = realm.objects('Entry')
    console.log(`Entries: ${entries.map((entry: any) => entry.audioFile)}`)
  })
}
