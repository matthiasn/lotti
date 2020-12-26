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
