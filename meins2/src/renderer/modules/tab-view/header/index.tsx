import React from 'react'

export function TabHeader() {
  return (
    <div className="tabs-header">
      <div className="tab-item add-tab">
        <span className="fa fa-plus" />
      </div>
      <div className="tab-item close-all">
        <span>5</span>
        <i className="fas fa-times" />
      </div>
      <div className="tab-items">
        <div className="tooltip">
          <div className="tab-item active" draggable="true">
            <span className="fa fa-times" />
          </div>
          <div className="tooltiptext">
            <h4>Complete PR</h4>
          </div>
        </div>
        <div className="tooltip">
          <div className="tab-item" draggable="true">
            <span className="fa fa-times" />
          </div>
          <div className="tooltiptext">
            <h4>Kickstart Migration</h4>
          </div>
        </div>
      </div>
    </div>
  )
}
