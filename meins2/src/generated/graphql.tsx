import { gql } from '@apollo/client'
import * as Apollo from '@apollo/client'
export type Maybe<T> = T | null
export type Exact<T extends { [key: string]: unknown }> = {
  [K in keyof T]: T[K]
}
export type MakeOptional<T, K extends keyof T> = Omit<T, K> &
  { [SubKey in K]?: Maybe<T[SubKey]> }
export type MakeMaybe<T, K extends keyof T> = Omit<T, K> &
  { [SubKey in K]: Maybe<T[SubKey]> }
/** All built-in and custom scalars, mapped to their actual values */
export type Scalars = {
  ID: string
  String: string
  Boolean: boolean
  Int: number
  Float: number
}

/** album details */
export type Album_Cfg = {
  __typename?: 'Album_cfg'
  active?: Maybe<Scalars['Boolean']>
  pvt?: Maybe<Scalars['Boolean']>
  title?: Maybe<Scalars['String']>
}

/** An artist from spotify */
export type Artist = {
  __typename?: 'Artist'
  id?: Maybe<Scalars['String']>
  name?: Maybe<Scalars['String']>
  uri?: Maybe<Scalars['String']>
}

/** Custom field stats item. */
export type AwardPointItem = {
  __typename?: 'AwardPointItem'
  date_string: Scalars['String']
  habit?: Maybe<Scalars['Int']>
  task?: Maybe<Scalars['Int']>
}

/** Award points result */
export type AwardPoints = {
  __typename?: 'AwardPoints'
  by_day?: Maybe<Array<Maybe<AwardPointItem>>>
  claimed?: Maybe<Scalars['Int']>
  total?: Maybe<Scalars['Int']>
}

/** Blood Pressure item. */
export type BloodPressureStatsItem = {
  __typename?: 'BloodPressureStatsItem'
  adjusted_ts?: Maybe<Scalars['ID']>
  bp_diastolic?: Maybe<Scalars['Float']>
  bp_systolic?: Maybe<Scalars['Float']>
  timestamp: Scalars['ID']
}

/** A briefing (plan for a specific day) */
export type Briefing = {
  __typename?: 'Briefing'
  comments?: Maybe<Array<Maybe<Entry>>>
  day?: Maybe<Scalars['String']>
  linked?: Maybe<Array<Maybe<Entry>>>
  timestamp: Scalars['ID']
  vclock?: Maybe<Array<Maybe<Vclock>>>
}

/** Custom field stats item. */
export type CustomFieldItem = {
  __typename?: 'CustomFieldItem'
  field: Scalars['String']
  value?: Maybe<Scalars['Float']>
  values?: Maybe<Array<Maybe<CustomFieldTsVal>>>
}

/** Custom field stats item. */
export type CustomFieldStatsItem = {
  __typename?: 'CustomFieldStatsItem'
  date_string: Scalars['String']
  fields?: Maybe<Array<Maybe<CustomFieldItem>>>
  tag?: Maybe<Scalars['String']>
}

/** Custom field stats item. */
export type CustomFieldTsVal = {
  __typename?: 'CustomFieldTsVal'
  ts: Scalars['ID']
  v?: Maybe<Scalars['Float']>
}

/** Logged time for specified day. */
export type DayStats = {
  __typename?: 'DayStats'
  by_saga?: Maybe<Array<Maybe<LoggedBySaga>>>
  by_story?: Maybe<Array<Maybe<LoggedByStory>>>
  by_ts?: Maybe<Array<Maybe<LoggedCalItem>>>
  by_ts_cal?: Maybe<Array<Maybe<LoggedCalItem>>>
  closed_tasks_cnt?: Maybe<Scalars['Int']>
  day: Scalars['String']
  done_tasks_cnt?: Maybe<Scalars['Int']>
  entry_count?: Maybe<Scalars['Int']>
  tasks_cnt?: Maybe<Scalars['Int']>
  /** Logged time in seconds */
  total_time: Scalars['Int']
  word_count?: Maybe<Scalars['Int']>
}

/** A journal entry */
export type Entry = {
  __typename?: 'Entry'
  adjusted_ts?: Maybe<Scalars['ID']>
  album_cfg?: Maybe<Album_Cfg>
  arrival_timestamp?: Maybe<Scalars['Float']>
  audio_file?: Maybe<Scalars['String']>
  comment_for?: Maybe<Scalars['ID']>
  comments?: Maybe<Array<Maybe<Entry>>>
  completed_time?: Maybe<Scalars['Int']>
  custom_field_cfg?: Maybe<Scalars['String']>
  custom_fields?: Maybe<Scalars['String']>
  dashboard_cfg?: Maybe<Scalars['String']>
  departure_timestamp?: Maybe<Scalars['Float']>
  entry_type?: Maybe<Scalars['String']>
  for_day?: Maybe<Scalars['String']>
  git_commit?: Maybe<GitCommit>
  habit?: Maybe<Scalars['String']>
  hidden?: Maybe<Scalars['Boolean']>
  img_file?: Maybe<Scalars['String']>
  img_rel_path?: Maybe<Scalars['String']>
  last_saved?: Maybe<Scalars['ID']>
  latitude?: Maybe<Scalars['Float']>
  linked?: Maybe<Array<Maybe<Entry>>>
  linked_cnt?: Maybe<Scalars['Int']>
  linked_saga?: Maybe<Scalars['ID']>
  longitude?: Maybe<Scalars['Float']>
  md?: Maybe<Scalars['String']>
  mentions?: Maybe<Array<Maybe<Scalars['String']>>>
  perm_tags?: Maybe<Array<Maybe<Scalars['String']>>>
  primary_story?: Maybe<Scalars['ID']>
  problem_cfg?: Maybe<Problem_Cfg>
  questionnaires?: Maybe<Scalars['String']>
  reward?: Maybe<Reward>
  saga_cfg?: Maybe<Saga>
  saga_name?: Maybe<Scalars['String']>
  spotify?: Maybe<Spotify>
  starred?: Maybe<Scalars['Boolean']>
  stars?: Maybe<Scalars['Int']>
  story?: Maybe<Story>
  story_cfg?: Maybe<Story>
  story_name?: Maybe<Scalars['String']>
  tags?: Maybe<Array<Maybe<Scalars['String']>>>
  task?: Maybe<Task>
  text?: Maybe<Scalars['String']>
  timestamp: Scalars['ID']
  vclock?: Maybe<Array<Maybe<Vclock>>>
}

/** GeoJSON Feature */
export type GeoFeature = {
  __typename?: 'GeoFeature'
  geometry?: Maybe<GeoGeometry>
  properties?: Maybe<GeoProperties>
  type?: Maybe<Scalars['String']>
}

/** GeoJSON geometry */
export type GeoGeometry = {
  __typename?: 'GeoGeometry'
  coordinates?: Maybe<Array<Maybe<Scalars['Float']>>>
  type?: Maybe<Scalars['String']>
}

/** GeoJSON Line Feature */
export type GeoLineFeature = {
  __typename?: 'GeoLineFeature'
  geometry?: Maybe<GeoLineGeometry>
  properties?: Maybe<GeoLineProperties>
  type?: Maybe<Scalars['String']>
}

/** GeoJSON Line Geometry */
export type GeoLineGeometry = {
  __typename?: 'GeoLineGeometry'
  coordinates?: Maybe<Array<Maybe<Array<Maybe<Scalars['Float']>>>>>
  type?: Maybe<Scalars['String']>
}

/** GeoJSON Line Properties */
export type GeoLineProperties = {
  __typename?: 'GeoLineProperties'
  activity?: Maybe<Scalars['String']>
}

/** GeoJSON properties */
export type GeoProperties = {
  __typename?: 'GeoProperties'
  accuracy?: Maybe<Scalars['Float']>
  activity?: Maybe<Scalars['String']>
  data?: Maybe<Scalars['String']>
  entry?: Maybe<Entry>
  entry_type?: Maybe<Scalars['String']>
  timestamp: Scalars['ID']
}

/** git abbreviated-parent details */
export type GitAuthor = {
  __typename?: 'GitAuthor'
  date?: Maybe<Scalars['String']>
  email?: Maybe<Scalars['String']>
  name?: Maybe<Scalars['String']>
}

/** git commit details */
export type GitCommit = {
  __typename?: 'GitCommit'
  abbreviated_commit?: Maybe<Scalars['String']>
  abbreviated_parent?: Maybe<Scalars['String']>
  abbreviated_tree?: Maybe<Scalars['String']>
  author?: Maybe<GitAuthor>
  commit?: Maybe<Scalars['String']>
  parent?: Maybe<Scalars['String']>
  refs?: Maybe<Scalars['String']>
  repo_name?: Maybe<Scalars['String']>
  subject?: Maybe<Scalars['String']>
  tree?: Maybe<Scalars['String']>
}

/** Custom field stats item. */
export type GitStatsItem = {
  __typename?: 'GitStatsItem'
  commits?: Maybe<Scalars['Int']>
  date_string: Scalars['String']
}

/** habit details */
export type Habit1 = {
  __typename?: 'Habit1'
  penalty?: Maybe<Scalars['Int']>
  points?: Maybe<Scalars['Int']>
  priority?: Maybe<Scalars['String']>
}

/** Habit success for criteria */
export type HabitCriteria = {
  __typename?: 'HabitCriteria'
  day?: Maybe<Scalars['String']>
  habit_text?: Maybe<Scalars['String']>
  habit_ts?: Maybe<Scalars['ID']>
  success?: Maybe<Scalars['Boolean']>
  values?: Maybe<Array<Maybe<HabitCriterion>>>
}

/** Habit success for single criterion */
export type HabitCriterion = {
  __typename?: 'HabitCriterion'
  idx?: Maybe<Scalars['Int']>
  success?: Maybe<Scalars['Boolean']>
  v?: Maybe<Scalars['Float']>
}

/** Single habit status for day. */
export type HabitSuccess = {
  __typename?: 'HabitSuccess'
  completed?: Maybe<Array<Maybe<HabitCriteria>>>
  habit_entry?: Maybe<Entry>
}

/** Logged time by story. */
export type LoggedBySaga = {
  __typename?: 'LoggedBySaga'
  /** Logged time in seconds */
  logged?: Maybe<Scalars['Int']>
  saga?: Maybe<Saga>
}

/** Logged time by story. */
export type LoggedByStory = {
  __typename?: 'LoggedByStory'
  /** Logged time in seconds */
  logged?: Maybe<Scalars['Int']>
  story?: Maybe<Story>
}

/** Logged time item. */
export type LoggedCalItem = {
  __typename?: 'LoggedCalItem'
  adjusted_ts?: Maybe<Scalars['ID']>
  comment_for?: Maybe<Scalars['ID']>
  /** Completed time in seconds */
  completed?: Maybe<Scalars['Int']>
  /** Manually logged time in seconds */
  manual?: Maybe<Scalars['Int']>
  md?: Maybe<Scalars['String']>
  parent?: Maybe<Entry>
  story?: Maybe<Story>
  /** Summed time in seconds */
  summed?: Maybe<Scalars['Int']>
  text?: Maybe<Scalars['String']>
  timestamp: Scalars['ID']
}

/** Config of a problem */
export type Problem_Cfg = {
  __typename?: 'Problem_cfg'
  active?: Maybe<Scalars['Boolean']>
  name?: Maybe<Scalars['String']>
  pvt?: Maybe<Scalars['Boolean']>
}

/** Root of all queries. */
export type QueryRoot = {
  __typename?: 'QueryRoot'
  /** Number of currently active threads. */
  active_threads?: Maybe<Scalars['Int']>
  /** award points */
  award_points?: Maybe<AwardPoints>
  /** Blood Pressure for number of days */
  bp_field_stats?: Maybe<Array<Maybe<BloodPressureStatsItem>>>
  /** Briefing for specified day. */
  briefing?: Maybe<Briefing>
  /** List of all existing briefings. */
  briefings?: Maybe<Array<Maybe<Briefing>>>
  /** Completed tasks count. */
  completed_count?: Maybe<Scalars['Int']>
  /** Custom field stats for tag and number of days */
  custom_field_stats?: Maybe<Array<Maybe<CustomFieldStatsItem>>>
  /** Custom field stats for tag and day */
  custom_field_stats_by_day?: Maybe<CustomFieldStatsItem>
  /** Custom field stats for tag and day */
  custom_fields_by_days?: Maybe<Array<Maybe<CustomFieldStatsItem>>>
  day_stats?: Maybe<Array<Maybe<DayStats>>>
  /** Entry for given timestamp. */
  entry_by_ts?: Maybe<Entry>
  /** Number of entries. */
  entry_count?: Maybe<Scalars['Int']>
  /** Git commit stats for number of days */
  git_stats?: Maybe<Array<Maybe<GitStatsItem>>>
  habits_success?: Maybe<Array<Maybe<HabitSuccess>>>
  habits_success_by_day?: Maybe<Array<Maybe<HabitCriteria>>>
  /** List of all hashtags. */
  hashtags?: Maybe<Array<Maybe<Scalars['String']>>>
  /** Hours logged. */
  hours_logged?: Maybe<Scalars['Int']>
  /** List of geo coordinated between from and to. */
  lines_by_days?: Maybe<Array<Maybe<GeoLineFeature>>>
  /** List of geo coordinated between from and to. */
  locations_by_days?: Maybe<Array<Maybe<GeoFeature>>>
  logged_time?: Maybe<DayStats>
  /** Result count for given query. */
  match_count?: Maybe<Scalars['Int']>
  /** People count. */
  mention_count?: Maybe<Scalars['Int']>
  /** List of all mentions. */
  mentions?: Maybe<Array<Maybe<Scalars['String']>>>
  /** List of open tasks. */
  open_tasks?: Maybe<Array<Maybe<Entry>>>
  /** PID of the backend process. */
  pid?: Maybe<Scalars['Int']>
  /** List of all private hashtags. */
  pvt_hashtags?: Maybe<Array<Maybe<Scalars['String']>>>
  /** filled out questionnaires */
  questionnaires?: Maybe<Array<Maybe<QuestionnaireItem>>>
  /** filled out questionnaires for array of date strings */
  questionnaires_by_days?: Maybe<Array<Maybe<QuestionnaireItem>>>
  /** List of all existing sagas. */
  sagas?: Maybe<Array<Maybe<Saga>>>
  /** List of started tasks. */
  started_tasks?: Maybe<Array<Maybe<Entry>>>
  /** List of all existing stories. */
  stories?: Maybe<Array<Maybe<Story>>>
  /** List of entries for given query. */
  tab_search?: Maybe<Array<Maybe<Entry>>>
  /** Tag count. */
  tag_count?: Maybe<Scalars['Int']>
  /** Usage stats by day */
  usage_by_day?: Maybe<UsageStatsItem>
  /** List of waiting habits. */
  waiting_habits?: Maybe<Array<Maybe<Entry>>>
  /** Word count. */
  word_count?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootAward_PointsArgs = {
  days?: Maybe<Scalars['Int']>
  offset?: Maybe<Scalars['Int']>
  prio?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootBp_Field_StatsArgs = {
  days?: Maybe<Scalars['Int']>
  offset?: Maybe<Scalars['Int']>
  prio?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootBriefingArgs = {
  day?: Maybe<Scalars['String']>
  prio?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootBriefingsArgs = {
  prio?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootCompleted_CountArgs = {
  prio?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootCustom_Field_StatsArgs = {
  days?: Maybe<Scalars['Int']>
  offset?: Maybe<Scalars['Int']>
  prio?: Maybe<Scalars['Int']>
  tag?: Maybe<Scalars['String']>
}

/** Root of all queries. */
export type QueryRootCustom_Field_Stats_By_DayArgs = {
  day?: Maybe<Scalars['String']>
  prio?: Maybe<Scalars['Int']>
  tag?: Maybe<Scalars['String']>
}

/** Root of all queries. */
export type QueryRootCustom_Fields_By_DaysArgs = {
  day_strings?: Maybe<Array<Maybe<Scalars['String']>>>
  prio?: Maybe<Scalars['Int']>
  tags?: Maybe<Array<Maybe<Scalars['String']>>>
}

/** Root of all queries. */
export type QueryRootDay_StatsArgs = {
  days: Scalars['Int']
  prio?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootEntry_By_TsArgs = {
  ts?: Maybe<Scalars['ID']>
}

/** Root of all queries. */
export type QueryRootEntry_CountArgs = {
  prio?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootGit_StatsArgs = {
  days?: Maybe<Scalars['Int']>
  offset?: Maybe<Scalars['Int']>
  prio?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootHabits_SuccessArgs = {
  days?: Maybe<Scalars['Int']>
  offset?: Maybe<Scalars['Int']>
  prio?: Maybe<Scalars['Int']>
  pvt?: Maybe<Scalars['Boolean']>
}

/** Root of all queries. */
export type QueryRootHabits_Success_By_DayArgs = {
  day_strings?: Maybe<Array<Maybe<Scalars['String']>>>
  prio?: Maybe<Scalars['Int']>
  pvt?: Maybe<Scalars['Boolean']>
}

/** Root of all queries. */
export type QueryRootHashtagsArgs = {
  prio?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootHours_LoggedArgs = {
  prio?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootLines_By_DaysArgs = {
  accuracy?: Maybe<Scalars['Int']>
  from?: Maybe<Scalars['String']>
  to?: Maybe<Scalars['String']>
}

/** Root of all queries. */
export type QueryRootLocations_By_DaysArgs = {
  from?: Maybe<Scalars['String']>
  to?: Maybe<Scalars['String']>
}

/** Root of all queries. */
export type QueryRootLogged_TimeArgs = {
  day?: Maybe<Scalars['String']>
  prio?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootMatch_CountArgs = {
  prio?: Maybe<Scalars['Int']>
  query?: Maybe<Scalars['String']>
}

/** Root of all queries. */
export type QueryRootMention_CountArgs = {
  prio?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootMentionsArgs = {
  prio?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootOpen_TasksArgs = {
  prio?: Maybe<Scalars['Int']>
  pvt?: Maybe<Scalars['Boolean']>
}

/** Root of all queries. */
export type QueryRootPvt_HashtagsArgs = {
  prio?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootQuestionnairesArgs = {
  days?: Maybe<Scalars['Int']>
  k?: Maybe<Scalars['String']>
  offset?: Maybe<Scalars['Int']>
  prio?: Maybe<Scalars['Int']>
  tag?: Maybe<Scalars['String']>
}

/** Root of all queries. */
export type QueryRootQuestionnaires_By_DaysArgs = {
  day_strings?: Maybe<Array<Maybe<Scalars['String']>>>
  k?: Maybe<Scalars['String']>
  prio?: Maybe<Scalars['Int']>
  tag?: Maybe<Scalars['String']>
}

/** Root of all queries. */
export type QueryRootSagasArgs = {
  prio?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootStarted_TasksArgs = {
  on_hold?: Maybe<Scalars['Boolean']>
  prio?: Maybe<Scalars['Int']>
  pvt?: Maybe<Scalars['Boolean']>
}

/** Root of all queries. */
export type QueryRootStoriesArgs = {
  prio?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootTab_SearchArgs = {
  flagged?: Maybe<Scalars['Boolean']>
  from?: Maybe<Scalars['String']>
  incremental?: Maybe<Scalars['Boolean']>
  n?: Maybe<Scalars['Int']>
  prio?: Maybe<Scalars['Int']>
  pvt?: Maybe<Scalars['Boolean']>
  query?: Maybe<Scalars['String']>
  starred?: Maybe<Scalars['Boolean']>
  story?: Maybe<Scalars['ID']>
  tab?: Maybe<Scalars['String']>
  to?: Maybe<Scalars['String']>
}

/** Root of all queries. */
export type QueryRootTag_CountArgs = {
  prio?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootUsage_By_DayArgs = {
  geohash_precision?: Maybe<Scalars['Int']>
}

/** Root of all queries. */
export type QueryRootWaiting_HabitsArgs = {
  prio?: Maybe<Scalars['Int']>
  pvt?: Maybe<Scalars['Boolean']>
}

/** Root of all queries. */
export type QueryRootWord_CountArgs = {
  prio?: Maybe<Scalars['Int']>
}

/** An aggregration for a filled out questionnaire. */
export type QuestionnaireItem = {
  __typename?: 'QuestionnaireItem'
  adjusted_ts?: Maybe<Scalars['ID']>
  agg?: Maybe<Scalars['String']>
  date_string?: Maybe<Scalars['String']>
  label?: Maybe<Scalars['String']>
  score?: Maybe<Scalars['Int']>
  starred?: Maybe<Scalars['Boolean']>
  tag?: Maybe<Scalars['String']>
  timestamp: Scalars['ID']
}

export type Reward = {
  __typename?: 'Reward'
  claimed?: Maybe<Scalars['Boolean']>
  claimed_ts?: Maybe<Scalars['ID']>
  points?: Maybe<Scalars['Int']>
}

/** A saga */
export type Saga = {
  __typename?: 'Saga'
  active?: Maybe<Scalars['Boolean']>
  pvt?: Maybe<Scalars['Boolean']>
  saga_name?: Maybe<Scalars['String']>
  text?: Maybe<Scalars['String']>
  timestamp: Scalars['ID']
  vclock?: Maybe<Array<Maybe<Vclock>>>
}

/** A spotify listen event */
export type Spotify = {
  __typename?: 'Spotify'
  album_uri?: Maybe<Scalars['String']>
  artists?: Maybe<Array<Maybe<Artist>>>
  id?: Maybe<Scalars['String']>
  image?: Maybe<Scalars['String']>
  name?: Maybe<Scalars['String']>
  uri?: Maybe<Scalars['String']>
}

/** A story */
export type Story = {
  __typename?: 'Story'
  active?: Maybe<Scalars['Boolean']>
  badge_color?: Maybe<Scalars['String']>
  font_color?: Maybe<Scalars['String']>
  pvt?: Maybe<Scalars['Boolean']>
  /** Saga that the story belongs to. */
  saga?: Maybe<Saga>
  story_name?: Maybe<Scalars['String']>
  text?: Maybe<Scalars['String']>
  timestamp: Scalars['ID']
  vclock?: Maybe<Array<Maybe<Vclock>>>
}

/** task details for entry. */
export type Task = {
  __typename?: 'Task'
  closed?: Maybe<Scalars['Boolean']>
  closed_ts?: Maybe<Scalars['String']>
  completion_ts?: Maybe<Scalars['String']>
  done?: Maybe<Scalars['Boolean']>
  estimate_m?: Maybe<Scalars['Int']>
  on_hold?: Maybe<Scalars['Boolean']>
  points?: Maybe<Scalars['Int']>
  priority?: Maybe<Scalars['String']>
}

/** Usage stats item. */
export type UsageStatsItem = {
  __typename?: 'UsageStatsItem'
  dur?: Maybe<Scalars['Int']>
  entries?: Maybe<Scalars['Int']>
  geohashes?: Maybe<Array<Maybe<Scalars['String']>>>
  habits?: Maybe<Scalars['Int']>
  hashtags?: Maybe<Scalars['Int']>
  hours_logged?: Maybe<Scalars['Float']>
  id_hash?: Maybe<Scalars['String']>
  os?: Maybe<Scalars['String']>
  sagas?: Maybe<Scalars['Int']>
  stories?: Maybe<Scalars['Int']>
  tasks?: Maybe<Scalars['Int']>
  tasks_done?: Maybe<Scalars['Int']>
  words?: Maybe<Scalars['Int']>
}

/** habit details */
export type Vclock = {
  __typename?: 'Vclock'
  clock?: Maybe<Scalars['Int']>
  node?: Maybe<Scalars['ID']>
}

export type StatsQueryVariables = Exact<{ [key: string]: never }>

export type StatsQuery = { __typename?: 'QueryRoot' } & Pick<
  QueryRoot,
  | 'active_threads'
  | 'completed_count'
  | 'tag_count'
  | 'entry_count'
  | 'mention_count'
  | 'word_count'
  | 'hours_logged'
> & {
    open_tasks?: Maybe<
      Array<Maybe<{ __typename?: 'Entry' } & Pick<Entry, 'timestamp'>>>
    >
  }

export type OpenTasksQueryVariables = Exact<{ [key: string]: never }>

export type OpenTasksQuery = { __typename?: 'QueryRoot' } & {
  open_tasks?: Maybe<
    Array<
      Maybe<
        { __typename?: 'Entry' } & Pick<Entry, 'timestamp' | 'md'> & {
            task?: Maybe<{ __typename?: 'Task' } & Pick<Task, 'priority'>>
          }
      >
    >
  >
}

export const StatsDocument = gql`
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

/**
 * __useStatsQuery__
 *
 * To run a query within a React component, call `useStatsQuery` and pass it any options that fit your needs.
 * When your component renders, `useStatsQuery` returns an object from Apollo Client that contains loading, error, and data properties
 * you can use to render your UI.
 *
 * @param baseOptions options that will be passed into the query, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options;
 *
 * @example
 * const { data, loading, error } = useStatsQuery({
 *   variables: {
 *   },
 * });
 */
export function useStatsQuery(
  baseOptions?: Apollo.QueryHookOptions<StatsQuery, StatsQueryVariables>,
) {
  return Apollo.useQuery<StatsQuery, StatsQueryVariables>(
    StatsDocument,
    baseOptions,
  )
}
export function useStatsLazyQuery(
  baseOptions?: Apollo.LazyQueryHookOptions<StatsQuery, StatsQueryVariables>,
) {
  return Apollo.useLazyQuery<StatsQuery, StatsQueryVariables>(
    StatsDocument,
    baseOptions,
  )
}
export type StatsQueryHookResult = ReturnType<typeof useStatsQuery>
export type StatsLazyQueryHookResult = ReturnType<typeof useStatsLazyQuery>
export type StatsQueryResult = Apollo.QueryResult<
  StatsQuery,
  StatsQueryVariables
>
export const OpenTasksDocument = gql`
  query openTasks {
    open_tasks {
      timestamp
      md
      task {
        priority
      }
    }
  }
`

/**
 * __useOpenTasksQuery__
 *
 * To run a query within a React component, call `useOpenTasksQuery` and pass it any options that fit your needs.
 * When your component renders, `useOpenTasksQuery` returns an object from Apollo Client that contains loading, error, and data properties
 * you can use to render your UI.
 *
 * @param baseOptions options that will be passed into the query, supported options are listed on: https://www.apollographql.com/docs/react/api/react-hooks/#options;
 *
 * @example
 * const { data, loading, error } = useOpenTasksQuery({
 *   variables: {
 *   },
 * });
 */
export function useOpenTasksQuery(
  baseOptions?: Apollo.QueryHookOptions<
    OpenTasksQuery,
    OpenTasksQueryVariables
  >,
) {
  return Apollo.useQuery<OpenTasksQuery, OpenTasksQueryVariables>(
    OpenTasksDocument,
    baseOptions,
  )
}
export function useOpenTasksLazyQuery(
  baseOptions?: Apollo.LazyQueryHookOptions<
    OpenTasksQuery,
    OpenTasksQueryVariables
  >,
) {
  return Apollo.useLazyQuery<OpenTasksQuery, OpenTasksQueryVariables>(
    OpenTasksDocument,
    baseOptions,
  )
}
export type OpenTasksQueryHookResult = ReturnType<typeof useOpenTasksQuery>
export type OpenTasksLazyQueryHookResult = ReturnType<
  typeof useOpenTasksLazyQuery
>
export type OpenTasksQueryResult = Apollo.QueryResult<
  OpenTasksQuery,
  OpenTasksQueryVariables
>
