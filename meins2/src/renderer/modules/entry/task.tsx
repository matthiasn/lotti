import React from 'react'
import { Entry, Task } from '../../../generated/graphql'

export function TaskView({ item }: { item: Entry }) {
  const task: Task = item.task

  if (!task) {
    return null
  }

  return (
    <div className="task-details">
      <div className="overview">
        <span className="click">
          <i className="fas fa-check-circle" />
        </span>
        <span className="click closed">
          <i className="fas fa-times-circle" />
        </span>
        <span className="click">
          <i className="fas fa-cog" />
        </span>
      </div>
    </div>
  )
}
