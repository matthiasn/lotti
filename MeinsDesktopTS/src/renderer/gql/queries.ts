import {gql} from '@apollo/client'

export const TAB_SEARCH = gql`
  query {
    tabSearch(input: {take: 1000, skip: 0, query: "#spotify"}) {
      md
      timestamp
      tags
      created
      spotify {
        name
        image
        artists {
          name
          uri
        }
      }
    }
  }
`
