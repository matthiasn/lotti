import React, {useEffect, useState} from 'react'
import {ASSEMBLY_API_KEY, DOC_ID} from './secrets'

export function AnalyzeTranscript() {
  const [status, setStatus] = useState('idle')
  const [data, setData] = useState()
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
      const json = await response.json()
      console.log(json)
      const data = await response.json()
      setData(data)
      setStatus('fetched')
    }
    fetchData()
  }, [])

  return (
    <div>
      <h1>Transcript Analytics</h1>
    </div>
  )
}
