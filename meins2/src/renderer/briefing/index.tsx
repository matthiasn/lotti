import React from 'react'
import { OpenTasks } from './open-tasks'
import { StartedTasks } from './started-tasks'

export function Briefing() {
  return (
    <div className="briefing-container">
      <div className="tile-tabs">
        <div className="journal">
          <div className="journal-entries">
            <div className="briefing">
              <div className="briefing-header"></div>
              <div className="scroll">
                <StartedTasks />
                <OpenTasks />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
