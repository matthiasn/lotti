import React from 'react'
import { toggleSettings } from '../../helpers/nav'

export function SettingsScreen() {
  return (
    <div className={'flex-container'}>
      <div className={'grid'}>
        <div className="wrapper">
          <div className="menu">
            <div className="menu-header">
              <i className="far toggle fa-user-secret" />
            </div>
          </div>
          <div className="config">
            <div className="menu">
              <h1>Settings</h1>
              <div className="items">
                <div className="menu-item highlight">Sagas</div>
                <div className="menu-item">Stories</div>
                <div className="menu-item">Albums</div>
                <div className="menu-item">Custom Fields</div>
                <div className="menu-item">Habits</div>
                <div className="menu-item">Dashboards</div>
                <div className="menu-item">Metrics</div>
                <div className="menu-item">Synchronization</div>
                <div className="menu-item">Photos</div>
                <div className="menu-item">Localization</div>
                <div className="menu-item">Usage Stats</div>
                <div
                  className="menu-item exit"
                  onClick={() => toggleSettings()}
                >
                  Exit
                </div>
              </div>
            </div>
          </div>
          <div className="cfg footer">
            <div className="stats-string">
              <div>
                meins <span className="highlight">0.6.323</span> beta | 137557
                entries | 4317 tags | 631 stories | 610 people | 18877 hours |
                1062306 words | 468 open tasks | 5192 done | 1176 closed | 4156
                #import | 2797 #screenshot | threads | PID <span>507 | </span> ©
                Matthias Nehlsen
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
