import React from 'react'
import { Entry, useOpenTasksQuery } from '../../../generated/graphql'
import moment from 'moment'

function OpenTask({ item }: { item: Entry }) {
  const prio = `${item.task?.priority || ''}`.replace(':', '')
  const age = moment(parseInt(item.timestamp)).fromNow(true)

  return (
    <tr className="task">
      <td>
        <span className={`prio ${prio}`}>{prio}</span>
      </td>
      <td className="time">{age}</td>
      <td className="text">{item.text || item.md}</td>
    </tr>
  )
}

export function OpenTasks() {
  const data = useOpenTasksQuery({
    fetchPolicy: 'cache-and-network',
  }).data

  if (!data) {
    return null
  }

  return (
    <div className="open-tasks">
      <table className="tasks">
        <tbody>
          <tr>
            <th className="xs">
              <i className="far fa-exclamation-triangle" />
            </th>
            <th>age</th>
            <th>
              open tasks
              <i className="fas fa-search" />
              <input value="" />
            </th>
          </tr>
          {data?.open_tasks?.map((item: Entry) => (
            <OpenTask item={item} />
          ))}
        </tbody>
      </table>
    </div>
  )
}
