import React from 'react'

export enum TabSides {
  'left',
  'right',
}

export function TabView({ side }: { side: TabSides }) {
  return (
    <div className={side.toString()}>
      <div className="tile-tabs">
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
        <div className="journal">
          <div id={side.toString()} className="journal-entries">
            <div>
              <div>
                <div>
                  <div className="entry-with-comments">
                    <div draggable="true" className="entry">
                      <div className="drag">
                        <div className="header-1">
                          <div>
                            <div className="story-select">
                              <div className="story story-name">
                                <i className="fal fa-book " />
                                <span>meins: Health integration</span>
                              </div>
                            </div>
                          </div>
                          <div>
                            <span className="link-btn">linked: 1</span>
                          </div>
                        </div>
                        <div className="header">
                          <div className="action-row">
                            <div className="datetime">
                              <a>
                                <time className="ts">04.09.2019, 19:58:56</time>
                              </a>
                            </div>
                            <div className="actions">
                              <div className="items">
                                <span className="cf-hashtag-select">
                                  <span>
                                    <i className="fa fa-hashtag toggle " />
                                  </span>
                                </span>
                                <i className="fa fa-stopwatch toggle" />
                                <i className="fa fa-comment toggle" />
                                <i className="fa toggle far fa-arrow-alt-from-left" />
                                <span className="delete-btn">
                                  <i className="fa fa-trash-alt toggle" />
                                </span>
                                <i className="fa fa-bug toggle" />
                              </div>
                              <i className="fa toggle fa-star" />
                              <i className="fa toggle fa-flag" />
                            </div>
                          </div>
                        </div>
                      </div>
                      <div className="">
                        <div className="entry-text">
                          <div className="RichEditor-controls edit-menu">
                            <i className="fa far fa-save fa-wide" />
                            <i className="fa far fa-bold fa-wide" />
                            <i className="fa far fa-italic fa-wide" />
                            <i className="fa far fa-underline fa-wide" />
                            <i className="fa far fa-code fa-wide" />
                            <i className="fa far fa-strikethrough fa-wide" />
                            <i className="fa far fa-heading" />
                            <i className="fa far fa-heading header-2" />
                            <i className="fa far fa-heading header-3" />
                            <i className="fa far fa-list-ul fa-wide active-button" />
                            <i className="fa far fa-list-ol fa-wide" />
                          </div>
                        </div>
                      </div>
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
                      <div className="entry-footer">
                        <div className="pomodoro">
                          <div className="dur">00:30:00</div>
                        </div>
                        <div className="hashtags">
                          <span className="hashtag">#task</span>
                          <span className="hashtag">#photo</span>
                          <span className="hashtag">#screenshot</span>
                          <span className="hashtag">#PR</span>
                        </div>
                        <div className="word-count" />
                      </div>
                    </div>
                    <div className="show-comments">
                      <span>show 1 comment</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
