import {gql} from '@apollo/client'

export const STATS = gql`
  query stats {
    completed_count
    tag_count
    entry_count
    mention_count
  }
`
