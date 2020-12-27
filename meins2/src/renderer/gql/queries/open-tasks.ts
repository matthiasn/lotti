import { gql } from '@apollo/client'

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
