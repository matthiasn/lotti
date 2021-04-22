import React, {useEffect, useState} from 'react'
import {ASSEMBLY_API_KEY, DOC_ID} from './secrets'

function pad(s: string, n: number) {
  return s.padStart(2, '0')
}

function millisecondsToHuman(ms: number) {
  const seconds = Math.floor((ms / 1000) % 60)
  const minutes = Math.floor((ms / 1000 / 60) % 60)
  const hours = Math.floor((ms  / 1000 / 3600 ) % 24)

  const humanized = [
    pad(hours.toString(), 2),
    pad(minutes.toString(), 2),
    pad(seconds.toString(), 2),
  ].join(':')

  return humanized
}

type Utterance = {
  end: number
  speaker: string
  start: number
  text: string
}

function msBySpeaker(utterances: Utterance[]) {
  const speakerSums = new Map<string, number>()
  utterances.forEach((utterance) => {
    const { end, start, speaker } = utterance
    const duration = end - start
    const prev = speakerSums.get(speaker) || 0
    speakerSums.set(speaker, prev + duration)
  })
  return speakerSums
}

export function AnalyzeTranscript() {
  const [status, setStatus] = useState('idle')
  const [data, setData] = useState<any>()
  console.log('ASSEMBLY_API_KEY', ASSEMBLY_API_KEY)

  useEffect(() => {
    const fetchData = async () => {
      setStatus('fetching')
      const response = await fetch(
        `https://api.assemblyai.com/v2/transcript/${DOC_ID}`,
        {
          headers: {
            'Authorization': ASSEMBLY_API_KEY,
          },
        }
      )
      const data = await response.json()
      console.log(data)
      setData(data)
      setStatus('fetched')
    }
    fetchData()
  }, [])

  const speakerSums = msBySpeaker(data.utterances)

  return (
    <div>
      <h1>Transcript Analytics</h1>
      <div>
        Speaker A: {millisecondsToHuman(speakerSums.get('A') || 0)}
      </div>
      <div>
        Speaker B: {millisecondsToHuman(speakerSums.get('B') || 0)}
      </div>
      {data && data.utterances.map(({end, speaker, start, text}: Utterance) => {
        return (
          <div className="utterance">
            {speaker}({millisecondsToHuman(start)}): {text}
          </div>
        )
      })}
    </div>
  )
}
