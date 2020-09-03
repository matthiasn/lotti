import {gql} from 'apollo-server'

export const typeDefs = gql`
  type GitAuthor {
    date: String
    email: String
    name: String
  }

  type GitCommit {
    abbreviated_commit: String
    abbreviated_parent: String
    abbreviated_tree: String
    author: GitAuthor
    commit: String
    parent: String
    refs: String
    repo_name: String
    subject: String
    tree: String
  }

  type AlbumCfg {
    active: Boolean
    pvt: Boolean
    title: String
  }

  type ProblemCfg {
    active: Boolean
    name: String
    pvt: Boolean
  }

  type Reward {
    claimed: Boolean
    claimed_ts: ID
    points: Int
  }

  type Saga {
    active: Boolean
    pvt: Boolean
    saga_name: String
    text: String
    timestamp: ID!
    vclock: [Vclock]
  }

  type Story {
    active: Boolean
    badge_color: String
    font_color: String
    pvt: Boolean
    saga: Saga
    story_name: String
    text: String
    timestamp: ID!
    vclock: [Vclock]
  }

  type Task {
    closed: Boolean
    closed_ts: String
    completion_ts: String
    done: Boolean
    estimate_m: Int
    on_hold: Boolean
    points: Int
    priority: String
  }

  type Artist {
    id: String
    name: String
    uri: String
  }

  type Spotify {
    album_uri: String
    artists: [Artist]
    id: String
    image: String
    name: String
    uri: String
  }

  type Vclock {
    clock: Int
    node: ID
  }

  type Entry {
    adjusted_ts: ID
    album_cfg: AlbumCfg
    arrival_timestamp: Float
    audio_file: String
    comment_for: ID
    comments: [Entry]
    completed_time: Int
    custom_field_cfg: String
    custom_fields: String
    dashboard_cfg: String
    departure_timestamp: Float
    entry_type: String
    for_day: String
    git_commit: GitCommit
    habit: String
    hidden: Boolean
    img_file: String
    img_rel_path: String
    last_saved: ID
    latitude: Float
    linked: [Entry]
    linked_cnt: Int
    linked_saga: ID
    longitude: Float
    md: String
    mentions: [String]
    perm_tags: [String]
    primary_story: ID
    problem_cfg: ProblemCfg
    questionnaires: String
    reward: Reward
    saga_cfg: Saga
    saga_name: String
    spotify: Spotify
    starred: Boolean
    stars: Int
    story: Story
    story_cfg: Story
    story_name: String
    tags: [String]
    task: Task
    text: String
    timestamp: ID!
    vclock: [Vclock]
  }

  type Query {
    tabSearch(
      flagged: Boolean
      from: String
      incremental: Boolean
      n: Int
      prio: Int
      pvt: Boolean
      query: String
      starred: Boolean
      story: ID
      tab: String
      to: String
    ): [Entry]
  }
`
