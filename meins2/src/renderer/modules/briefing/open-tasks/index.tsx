import React, { ChangeEvent, useState } from 'react'
import { Entry, useOpenTasksQuery } from '../../../../generated/graphql'
import moment from 'moment'
import { setTabQuery } from '../../../helpers/nav'
import { TabSides } from '../../tab-view'

function OpenTask({ item }: { item: Entry }) {
  const prio = `${item.task?.priority || ''}`.replace(':', '')
  const age = moment(parseInt(item.timestamp)).fromNow(true)

  return (
    <tr
      className="task"
      onClick={() => setTabQuery(TabSides.left, `${item.timestamp}`)}
    >
      <td>
        <span className={`prio ${prio}`}>{prio}</span>
      </td>
      <td className="time">{age}</td>
      <td className="text">{item.text || item.md}</td>
    </tr>
  )
}

export function OpenTasks() {
  const [filter, setFilter] = useState('')
  const openTasks = useOpenTasksQuery({
    fetchPolicy: 'cache-and-network',
  }).data?.open_tasks?.filter(
    (item) =>
      item?.text?.toLowerCase().includes(filter.toLowerCase()) ||
      filter.length === 0,
  )

  if (!openTasks) {
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
              <input
                value={filter}
                onChange={(ev) => setFilter(ev.target.value)}
              />
            </th>
          </tr>
          {openTasks?.map((item: Entry) => (
            <OpenTask item={item} key={`open-task-${item.timestamp}`} />
          ))}
        </tbody>
      </table>
    </div>
  )
}
