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
