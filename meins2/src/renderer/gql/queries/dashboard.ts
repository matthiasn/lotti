import { gql } from '@apollo/client'

const DASHBOARD = gql`
  query dashboard($days: Int, $pvt: Boolean, $offset: Int) {
    habits_success(days: $days, pvt: $pvt, offset: $offset) {
      completed {
        day
        habit_text
        habit_ts
        success
      }
    }
  }
`
