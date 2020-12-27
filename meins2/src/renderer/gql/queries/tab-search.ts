import { gql } from '@apollo/client'

export const TAB_SEARCH = gql`
  query tabSeach($n: Int, $query: String) {
    tab_search(n: $n, query: $query) {
      timestamp
      text
      md
      img_file
      longitude
      latitude
      starred
      comments {
        timestamp
        text
        md
        img_file
      }
      story {
        story_name
        timestamp
        saga {
          saga_name
          timestamp
        }
      }
      task {
        closed
        closed_ts
        completion_ts
        done
        estimate_m
        points
        priority
      }
      linked {
        timestamp
        text
        md
        story {
          story_name
          timestamp
          saga {
            saga_name
            timestamp
          }
        }
      }
    }
  }
`
