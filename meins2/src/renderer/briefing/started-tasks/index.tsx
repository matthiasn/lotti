import React from 'react'
import { Entry, useStartedTasksQuery } from '../../../generated/graphql'
import moment, { duration } from 'moment'

function StartedTask({ item }: { item: Entry }) {
  const prio = `${item.task?.priority || ''}`.replace(':', '')
  const age = moment(parseInt(item.timestamp)).fromNow(true)
  const allocated = moment
    .utc(duration(item.task?.estimate_m, 'minutes').asMilliseconds())
    .format('HH:mm')

  return (
    <tr className="task">
      <td className="tooltip">
        <i className="fal fa-info-circle" />
        <div className="tooltiptext">
          <div>
            <span className="story">{item.story?.story_name}</span>
          </div>
          <h4>{item.text}</h4>
          <div>
            <label>Task priority: </label>
            <strong>{prio}</strong>
          </div>
          <div>
            <label>Age: </label>
            <strong>{age}</strong>
          </div>
          <div>
            <label>Task idle for: </label>
            <strong>a while</strong>
          </div>
          <div>
            <label>Time allocated: </label>
            <strong>{allocated}</strong>
          </div>
          <div>
            <label>Time logged: </label>
            <strong>99:99:99</strong>
          </div>
          <div>
            <label>Time remaining: </label>
            <strong>99:99:99</strong>
          </div>
        </div>
      </td>
      <td className="progress"></td>
      <td className="text">{item.text}</td>
      <td className="last" />
    </tr>
  )
}

export function StartedTasks() {
  const data = useStartedTasksQuery({
    fetchPolicy: 'cache-and-network',
  }).data?.started_tasks?.filter(
    (item: Entry) => !item.task?.on_hold && !item.task?.done,
  )

  if (!data) {
    return null
  }

  return (
    <div className="started-tasks">
      <table className="tasks">
        <tbody>
          <tr>
            <th className="xs" />
            <th>progress</th>
            <th>
              <div>started tasks</div>
            </th>
          </tr>
          {data?.map((item: Entry) => (
            <StartedTask item={item} />
          ))}
        </tbody>
      </table>
    </div>
  )
}
