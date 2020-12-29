import { gql } from '@apollo/client'

export const AUTO_COMPLETE = gql`
  query autoComplete {
    hashtags
    mentions
  }
`
