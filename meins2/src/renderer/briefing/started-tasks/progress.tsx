import React from 'react'
import { Entry } from '../../../generated/graphql'

export function ProgressBar({ item }: { item: Entry }) {
  return (
    <td className="progress">
      <svg
        shapeRendering="crispEdges"
        style={{
          height: 12,
          width: 52,
          marginRight: 5,
          paddingTop: 3,
        }}
      >
        <g>
          <line x1={1} x2={50} y1={6} y2={6} strokeWidth={6} stroke="#DDD" />
          <line x1={1} x2={50} y1={6} y2={6} strokeWidth={6} stroke="red" />
          <line
            x1="24.996528259963892"
            x2="24.996528259963892"
            y1="1"
            y2="11"
            strokeWidth="2"
            stroke="#666"
          />
        </g>
      </svg>
    </td>
  )
}
