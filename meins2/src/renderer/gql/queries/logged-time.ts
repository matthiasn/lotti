import { gql } from '@apollo/client'

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
