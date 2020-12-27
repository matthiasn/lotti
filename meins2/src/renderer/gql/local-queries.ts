import { gql } from '@apollo/client'

export const GET_STATE = gql`
  query GetState {
    state @client {
      screen
      day
    }
  }
`
