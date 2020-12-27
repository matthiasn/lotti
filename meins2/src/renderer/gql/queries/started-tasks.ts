import { gql } from '@apollo/client'

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
