import { gql } from '@apollo/client'

export const STATS = gql`
  query stats {
    active_threads
    completed_count
    tag_count
    entry_count
    mention_count
    word_count
    hours_logged
    open_tasks {
      timestamp
    }
  }
`

export const OPEN_TASKS = gql`
  query openTasks {
    open_tasks {
      timestamp
      md
      text
      task {
        priority
      }
    }
  }
`

export const STARTED_TASKS = gql`
  query startedTasks {
    started_tasks {
      timestamp
      md
      text
      completed_time
      comments {
        timestamp
        completed_time
      }
      story {
        story_name
      }
      task {
        priority
        closed
        completion_ts
        estimate_m
        on_hold
        done
      }
    }
  }
`

export const LOGGED_TIME = gql`
  query loggedTime($day: String) {
    logged_time(day: $day) {
      day
      total_time
      entry_count
      word_count
      tasks_cnt
      closed_tasks_cnt
      done_tasks_cnt

      by_story {
        logged
        story {
          story_name
          timestamp
        }
      }

      by_ts {
        timestamp
        adjusted_ts
        md
        text

        story {
          timestamp
          saga {
            timestamp
            saga_name
          }
          story_name
          badge_color
          font_color
        }

        completed
        summed
        manual
        comment_for

        parent {
          timestamp
          text
          task {
            done
            closed
            estimate_m
            priority
          }
        }
      }

      by_ts_cal {
        timestamp
        adjusted_ts
        md
        text

        story {
          timestamp
          saga {
            timestamp
            saga_name
          }
          story_name
          badge_color
          font_color
        }

        completed
        summed
        manual
        comment_for

        parent {
          timestamp
          text
          task {
            done
            closed
            estimate_m
            priority
          }
        }
      }
    }
  }
`
