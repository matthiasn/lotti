import {GraphQLResolveInfo} from 'graphql'
import {Context} from '../types'
export type Maybe<T> = T | null
export type Exact<T extends {[key: string]: unknown}> = {[K in keyof T]: T[K]}
export type RequireFields<T, K extends keyof T> = {
  [X in Exclude<keyof T, K>]?: T[X]
} &
  {[P in K]-?: NonNullable<T[P]>}
/** All built-in and custom scalars, mapped to their actual values */
export type Scalars = {
  ID: string
  String: string
  Boolean: boolean
  Int: number
  Float: number
}

export type GitAuthor = {
  __typename?: 'GitAuthor'
  date?: Maybe<Scalars['String']>
  email?: Maybe<Scalars['String']>
  name?: Maybe<Scalars['String']>
}

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

export type AlbumCfg = {
  __typename?: 'AlbumCfg'
  active?: Maybe<Scalars['Boolean']>
  pvt?: Maybe<Scalars['Boolean']>
  title?: Maybe<Scalars['String']>
}

export type ProblemCfg = {
  __typename?: 'ProblemCfg'
  active?: Maybe<Scalars['Boolean']>
  name?: Maybe<Scalars['String']>
  pvt?: Maybe<Scalars['Boolean']>
}

export type Reward = {
  __typename?: 'Reward'
  claimed?: Maybe<Scalars['Boolean']>
  claimed_ts?: Maybe<Scalars['ID']>
  points?: Maybe<Scalars['Int']>
}

export type Saga = {
  __typename?: 'Saga'
  active?: Maybe<Scalars['Boolean']>
  pvt?: Maybe<Scalars['Boolean']>
  saga_name?: Maybe<Scalars['String']>
  text?: Maybe<Scalars['String']>
  timestamp: Scalars['ID']
  vclock?: Maybe<Array<Maybe<Vclock>>>
}

export type Story = {
  __typename?: 'Story'
  active?: Maybe<Scalars['Boolean']>
  badge_color?: Maybe<Scalars['String']>
  font_color?: Maybe<Scalars['String']>
  pvt?: Maybe<Scalars['Boolean']>
  saga?: Maybe<Saga>
  story_name?: Maybe<Scalars['String']>
  text?: Maybe<Scalars['String']>
  timestamp: Scalars['ID']
  vclock?: Maybe<Array<Maybe<Vclock>>>
}

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

export type Artist = {
  __typename?: 'Artist'
  id?: Maybe<Scalars['String']>
  name?: Maybe<Scalars['String']>
  uri?: Maybe<Scalars['String']>
}

export type Spotify = {
  __typename?: 'Spotify'
  album_uri?: Maybe<Scalars['String']>
  artists?: Maybe<Array<Maybe<Artist>>>
  id?: Maybe<Scalars['String']>
  image?: Maybe<Scalars['String']>
  name?: Maybe<Scalars['String']>
  uri?: Maybe<Scalars['String']>
}

export type Vclock = {
  __typename?: 'Vclock'
  clock?: Maybe<Scalars['Int']>
  node?: Maybe<Scalars['ID']>
}

export type Entry = {
  __typename?: 'Entry'
  adjusted_ts?: Maybe<Scalars['ID']>
  album_cfg?: Maybe<AlbumCfg>
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
  problem_cfg?: Maybe<ProblemCfg>
  questionnaires?: Maybe<Scalars['String']>
  created?: Maybe<Scalars['String']>
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

export type TabSearchInput = {
  flagged?: Maybe<Scalars['Boolean']>
  from?: Maybe<Scalars['String']>
  incremental?: Maybe<Scalars['Boolean']>
  skip?: Maybe<Scalars['Int']>
  take?: Maybe<Scalars['Int']>
  prio?: Maybe<Scalars['Int']>
  pvt?: Maybe<Scalars['Boolean']>
  query?: Maybe<Scalars['String']>
  starred?: Maybe<Scalars['Boolean']>
  story?: Maybe<Scalars['ID']>
  tab?: Maybe<Scalars['String']>
  to?: Maybe<Scalars['String']>
}

export type Query = {
  __typename?: 'Query'
  tabSearch?: Maybe<Array<Maybe<Entry>>>
}

export type QueryTabSearchArgs = {
  input: TabSearchInput
}

export type ResolverTypeWrapper<T> = Promise<T> | T

export type LegacyStitchingResolver<TResult, TParent, TContext, TArgs> = {
  fragment: string
  resolve: ResolverFn<TResult, TParent, TContext, TArgs>
}

export type NewStitchingResolver<TResult, TParent, TContext, TArgs> = {
  selectionSet: string
  resolve: ResolverFn<TResult, TParent, TContext, TArgs>
}
export type StitchingResolver<TResult, TParent, TContext, TArgs> =
  | LegacyStitchingResolver<TResult, TParent, TContext, TArgs>
  | NewStitchingResolver<TResult, TParent, TContext, TArgs>
export type Resolver<TResult, TParent = {}, TContext = {}, TArgs = {}> =
  | ResolverFn<TResult, TParent, TContext, TArgs>
  | StitchingResolver<TResult, TParent, TContext, TArgs>

export type ResolverFn<TResult, TParent, TContext, TArgs> = (
  parent: TParent,
  args: TArgs,
  context: TContext,
  info: GraphQLResolveInfo,
) => Promise<TResult> | TResult

export type SubscriptionSubscribeFn<TResult, TParent, TContext, TArgs> = (
  parent: TParent,
  args: TArgs,
  context: TContext,
  info: GraphQLResolveInfo,
) => AsyncIterator<TResult> | Promise<AsyncIterator<TResult>>

export type SubscriptionResolveFn<TResult, TParent, TContext, TArgs> = (
  parent: TParent,
  args: TArgs,
  context: TContext,
  info: GraphQLResolveInfo,
) => TResult | Promise<TResult>

export interface SubscriptionSubscriberObject<
  TResult,
  TKey extends string,
  TParent,
  TContext,
  TArgs
> {
  subscribe: SubscriptionSubscribeFn<
    {[key in TKey]: TResult},
    TParent,
    TContext,
    TArgs
  >
  resolve?: SubscriptionResolveFn<
    TResult,
    {[key in TKey]: TResult},
    TContext,
    TArgs
  >
}

export interface SubscriptionResolverObject<TResult, TParent, TContext, TArgs> {
  subscribe: SubscriptionSubscribeFn<any, TParent, TContext, TArgs>
  resolve: SubscriptionResolveFn<TResult, any, TContext, TArgs>
}

export type SubscriptionObject<
  TResult,
  TKey extends string,
  TParent,
  TContext,
  TArgs
> =
  | SubscriptionSubscriberObject<TResult, TKey, TParent, TContext, TArgs>
  | SubscriptionResolverObject<TResult, TParent, TContext, TArgs>

export type SubscriptionResolver<
  TResult,
  TKey extends string,
  TParent = {},
  TContext = {},
  TArgs = {}
> =
  | ((
      ...args: any[]
    ) => SubscriptionObject<TResult, TKey, TParent, TContext, TArgs>)
  | SubscriptionObject<TResult, TKey, TParent, TContext, TArgs>

export type TypeResolveFn<TTypes, TParent = {}, TContext = {}> = (
  parent: TParent,
  context: TContext,
  info: GraphQLResolveInfo,
) => Maybe<TTypes> | Promise<Maybe<TTypes>>

export type IsTypeOfResolverFn<T = {}> = (
  obj: T,
  info: GraphQLResolveInfo,
) => boolean | Promise<boolean>

export type NextResolverFn<T> = () => Promise<T>

export type DirectiveResolverFn<
  TResult = {},
  TParent = {},
  TContext = {},
  TArgs = {}
> = (
  next: NextResolverFn<TResult>,
  parent: TParent,
  args: TArgs,
  context: TContext,
  info: GraphQLResolveInfo,
) => TResult | Promise<TResult>

/** Mapping between all available schema types and the resolvers types */
export type ResolversTypes = {
  GitAuthor: ResolverTypeWrapper<GitAuthor>
  String: ResolverTypeWrapper<Scalars['String']>
  GitCommit: ResolverTypeWrapper<GitCommit>
  AlbumCfg: ResolverTypeWrapper<AlbumCfg>
  Boolean: ResolverTypeWrapper<Scalars['Boolean']>
  ProblemCfg: ResolverTypeWrapper<ProblemCfg>
  Reward: ResolverTypeWrapper<Reward>
  ID: ResolverTypeWrapper<Scalars['ID']>
  Int: ResolverTypeWrapper<Scalars['Int']>
  Saga: ResolverTypeWrapper<Saga>
  Story: ResolverTypeWrapper<Story>
  Task: ResolverTypeWrapper<Task>
  Artist: ResolverTypeWrapper<Artist>
  Spotify: ResolverTypeWrapper<Spotify>
  Vclock: ResolverTypeWrapper<Vclock>
  Entry: ResolverTypeWrapper<Entry>
  Float: ResolverTypeWrapper<Scalars['Float']>
  TabSearchInput: TabSearchInput
  Query: ResolverTypeWrapper<{}>
}

/** Mapping between all available schema types and the resolvers parents */
export type ResolversParentTypes = {
  GitAuthor: GitAuthor
  String: Scalars['String']
  GitCommit: GitCommit
  AlbumCfg: AlbumCfg
  Boolean: Scalars['Boolean']
  ProblemCfg: ProblemCfg
  Reward: Reward
  ID: Scalars['ID']
  Int: Scalars['Int']
  Saga: Saga
  Story: Story
  Task: Task
  Artist: Artist
  Spotify: Spotify
  Vclock: Vclock
  Entry: Entry
  Float: Scalars['Float']
  TabSearchInput: TabSearchInput
  Query: {}
}

export type GitAuthorResolvers<
  ContextType = Context,
  ParentType extends ResolversParentTypes['GitAuthor'] = ResolversParentTypes['GitAuthor']
> = {
  date?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  email?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  name?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  __isTypeOf?: IsTypeOfResolverFn<ParentType>
}

export type GitCommitResolvers<
  ContextType = Context,
  ParentType extends ResolversParentTypes['GitCommit'] = ResolversParentTypes['GitCommit']
> = {
  abbreviated_commit?: Resolver<
    Maybe<ResolversTypes['String']>,
    ParentType,
    ContextType
  >
  abbreviated_parent?: Resolver<
    Maybe<ResolversTypes['String']>,
    ParentType,
    ContextType
  >
  abbreviated_tree?: Resolver<
    Maybe<ResolversTypes['String']>,
    ParentType,
    ContextType
  >
  author?: Resolver<Maybe<ResolversTypes['GitAuthor']>, ParentType, ContextType>
  commit?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  parent?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  refs?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  repo_name?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  subject?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  tree?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  __isTypeOf?: IsTypeOfResolverFn<ParentType>
}

export type AlbumCfgResolvers<
  ContextType = Context,
  ParentType extends ResolversParentTypes['AlbumCfg'] = ResolversParentTypes['AlbumCfg']
> = {
  active?: Resolver<Maybe<ResolversTypes['Boolean']>, ParentType, ContextType>
  pvt?: Resolver<Maybe<ResolversTypes['Boolean']>, ParentType, ContextType>
  title?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  __isTypeOf?: IsTypeOfResolverFn<ParentType>
}

export type ProblemCfgResolvers<
  ContextType = Context,
  ParentType extends ResolversParentTypes['ProblemCfg'] = ResolversParentTypes['ProblemCfg']
> = {
  active?: Resolver<Maybe<ResolversTypes['Boolean']>, ParentType, ContextType>
  name?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  pvt?: Resolver<Maybe<ResolversTypes['Boolean']>, ParentType, ContextType>
  __isTypeOf?: IsTypeOfResolverFn<ParentType>
}

export type RewardResolvers<
  ContextType = Context,
  ParentType extends ResolversParentTypes['Reward'] = ResolversParentTypes['Reward']
> = {
  claimed?: Resolver<Maybe<ResolversTypes['Boolean']>, ParentType, ContextType>
  claimed_ts?: Resolver<Maybe<ResolversTypes['ID']>, ParentType, ContextType>
  points?: Resolver<Maybe<ResolversTypes['Int']>, ParentType, ContextType>
  __isTypeOf?: IsTypeOfResolverFn<ParentType>
}

export type SagaResolvers<
  ContextType = Context,
  ParentType extends ResolversParentTypes['Saga'] = ResolversParentTypes['Saga']
> = {
  active?: Resolver<Maybe<ResolversTypes['Boolean']>, ParentType, ContextType>
  pvt?: Resolver<Maybe<ResolversTypes['Boolean']>, ParentType, ContextType>
  saga_name?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  text?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  timestamp?: Resolver<ResolversTypes['ID'], ParentType, ContextType>
  vclock?: Resolver<
    Maybe<Array<Maybe<ResolversTypes['Vclock']>>>,
    ParentType,
    ContextType
  >
  __isTypeOf?: IsTypeOfResolverFn<ParentType>
}

export type StoryResolvers<
  ContextType = Context,
  ParentType extends ResolversParentTypes['Story'] = ResolversParentTypes['Story']
> = {
  active?: Resolver<Maybe<ResolversTypes['Boolean']>, ParentType, ContextType>
  badge_color?: Resolver<
    Maybe<ResolversTypes['String']>,
    ParentType,
    ContextType
  >
  font_color?: Resolver<
    Maybe<ResolversTypes['String']>,
    ParentType,
    ContextType
  >
  pvt?: Resolver<Maybe<ResolversTypes['Boolean']>, ParentType, ContextType>
  saga?: Resolver<Maybe<ResolversTypes['Saga']>, ParentType, ContextType>
  story_name?: Resolver<
    Maybe<ResolversTypes['String']>,
    ParentType,
    ContextType
  >
  text?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  timestamp?: Resolver<ResolversTypes['ID'], ParentType, ContextType>
  vclock?: Resolver<
    Maybe<Array<Maybe<ResolversTypes['Vclock']>>>,
    ParentType,
    ContextType
  >
  __isTypeOf?: IsTypeOfResolverFn<ParentType>
}

export type TaskResolvers<
  ContextType = Context,
  ParentType extends ResolversParentTypes['Task'] = ResolversParentTypes['Task']
> = {
  closed?: Resolver<Maybe<ResolversTypes['Boolean']>, ParentType, ContextType>
  closed_ts?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  completion_ts?: Resolver<
    Maybe<ResolversTypes['String']>,
    ParentType,
    ContextType
  >
  done?: Resolver<Maybe<ResolversTypes['Boolean']>, ParentType, ContextType>
  estimate_m?: Resolver<Maybe<ResolversTypes['Int']>, ParentType, ContextType>
  on_hold?: Resolver<Maybe<ResolversTypes['Boolean']>, ParentType, ContextType>
  points?: Resolver<Maybe<ResolversTypes['Int']>, ParentType, ContextType>
  priority?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  __isTypeOf?: IsTypeOfResolverFn<ParentType>
}

export type ArtistResolvers<
  ContextType = Context,
  ParentType extends ResolversParentTypes['Artist'] = ResolversParentTypes['Artist']
> = {
  id?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  name?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  uri?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  __isTypeOf?: IsTypeOfResolverFn<ParentType>
}

export type SpotifyResolvers<
  ContextType = Context,
  ParentType extends ResolversParentTypes['Spotify'] = ResolversParentTypes['Spotify']
> = {
  album_uri?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  artists?: Resolver<
    Maybe<Array<Maybe<ResolversTypes['Artist']>>>,
    ParentType,
    ContextType
  >
  id?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  image?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  name?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  uri?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  __isTypeOf?: IsTypeOfResolverFn<ParentType>
}

export type VclockResolvers<
  ContextType = Context,
  ParentType extends ResolversParentTypes['Vclock'] = ResolversParentTypes['Vclock']
> = {
  clock?: Resolver<Maybe<ResolversTypes['Int']>, ParentType, ContextType>
  node?: Resolver<Maybe<ResolversTypes['ID']>, ParentType, ContextType>
  __isTypeOf?: IsTypeOfResolverFn<ParentType>
}

export type EntryResolvers<
  ContextType = Context,
  ParentType extends ResolversParentTypes['Entry'] = ResolversParentTypes['Entry']
> = {
  adjusted_ts?: Resolver<Maybe<ResolversTypes['ID']>, ParentType, ContextType>
  album_cfg?: Resolver<
    Maybe<ResolversTypes['AlbumCfg']>,
    ParentType,
    ContextType
  >
  arrival_timestamp?: Resolver<
    Maybe<ResolversTypes['Float']>,
    ParentType,
    ContextType
  >
  audio_file?: Resolver<
    Maybe<ResolversTypes['String']>,
    ParentType,
    ContextType
  >
  comment_for?: Resolver<Maybe<ResolversTypes['ID']>, ParentType, ContextType>
  comments?: Resolver<
    Maybe<Array<Maybe<ResolversTypes['Entry']>>>,
    ParentType,
    ContextType
  >
  completed_time?: Resolver<
    Maybe<ResolversTypes['Int']>,
    ParentType,
    ContextType
  >
  custom_field_cfg?: Resolver<
    Maybe<ResolversTypes['String']>,
    ParentType,
    ContextType
  >
  custom_fields?: Resolver<
    Maybe<ResolversTypes['String']>,
    ParentType,
    ContextType
  >
  dashboard_cfg?: Resolver<
    Maybe<ResolversTypes['String']>,
    ParentType,
    ContextType
  >
  departure_timestamp?: Resolver<
    Maybe<ResolversTypes['Float']>,
    ParentType,
    ContextType
  >
  entry_type?: Resolver<
    Maybe<ResolversTypes['String']>,
    ParentType,
    ContextType
  >
  for_day?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  git_commit?: Resolver<
    Maybe<ResolversTypes['GitCommit']>,
    ParentType,
    ContextType
  >
  habit?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  hidden?: Resolver<Maybe<ResolversTypes['Boolean']>, ParentType, ContextType>
  img_file?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  img_rel_path?: Resolver<
    Maybe<ResolversTypes['String']>,
    ParentType,
    ContextType
  >
  last_saved?: Resolver<Maybe<ResolversTypes['ID']>, ParentType, ContextType>
  latitude?: Resolver<Maybe<ResolversTypes['Float']>, ParentType, ContextType>
  linked?: Resolver<
    Maybe<Array<Maybe<ResolversTypes['Entry']>>>,
    ParentType,
    ContextType
  >
  linked_cnt?: Resolver<Maybe<ResolversTypes['Int']>, ParentType, ContextType>
  linked_saga?: Resolver<Maybe<ResolversTypes['ID']>, ParentType, ContextType>
  longitude?: Resolver<Maybe<ResolversTypes['Float']>, ParentType, ContextType>
  md?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  mentions?: Resolver<
    Maybe<Array<Maybe<ResolversTypes['String']>>>,
    ParentType,
    ContextType
  >
  perm_tags?: Resolver<
    Maybe<Array<Maybe<ResolversTypes['String']>>>,
    ParentType,
    ContextType
  >
  primary_story?: Resolver<Maybe<ResolversTypes['ID']>, ParentType, ContextType>
  problem_cfg?: Resolver<
    Maybe<ResolversTypes['ProblemCfg']>,
    ParentType,
    ContextType
  >
  questionnaires?: Resolver<
    Maybe<ResolversTypes['String']>,
    ParentType,
    ContextType
  >
  created?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  reward?: Resolver<Maybe<ResolversTypes['Reward']>, ParentType, ContextType>
  saga_cfg?: Resolver<Maybe<ResolversTypes['Saga']>, ParentType, ContextType>
  saga_name?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  spotify?: Resolver<Maybe<ResolversTypes['Spotify']>, ParentType, ContextType>
  starred?: Resolver<Maybe<ResolversTypes['Boolean']>, ParentType, ContextType>
  stars?: Resolver<Maybe<ResolversTypes['Int']>, ParentType, ContextType>
  story?: Resolver<Maybe<ResolversTypes['Story']>, ParentType, ContextType>
  story_cfg?: Resolver<Maybe<ResolversTypes['Story']>, ParentType, ContextType>
  story_name?: Resolver<
    Maybe<ResolversTypes['String']>,
    ParentType,
    ContextType
  >
  tags?: Resolver<
    Maybe<Array<Maybe<ResolversTypes['String']>>>,
    ParentType,
    ContextType
  >
  task?: Resolver<Maybe<ResolversTypes['Task']>, ParentType, ContextType>
  text?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>
  timestamp?: Resolver<ResolversTypes['ID'], ParentType, ContextType>
  vclock?: Resolver<
    Maybe<Array<Maybe<ResolversTypes['Vclock']>>>,
    ParentType,
    ContextType
  >
  __isTypeOf?: IsTypeOfResolverFn<ParentType>
}

export type QueryResolvers<
  ContextType = Context,
  ParentType extends ResolversParentTypes['Query'] = ResolversParentTypes['Query']
> = {
  tabSearch?: Resolver<
    Maybe<Array<Maybe<ResolversTypes['Entry']>>>,
    ParentType,
    ContextType,
    RequireFields<QueryTabSearchArgs, 'input'>
  >
}

export type Resolvers<ContextType = Context> = {
  GitAuthor?: GitAuthorResolvers<ContextType>
  GitCommit?: GitCommitResolvers<ContextType>
  AlbumCfg?: AlbumCfgResolvers<ContextType>
  ProblemCfg?: ProblemCfgResolvers<ContextType>
  Reward?: RewardResolvers<ContextType>
  Saga?: SagaResolvers<ContextType>
  Story?: StoryResolvers<ContextType>
  Task?: TaskResolvers<ContextType>
  Artist?: ArtistResolvers<ContextType>
  Spotify?: SpotifyResolvers<ContextType>
  Vclock?: VclockResolvers<ContextType>
  Entry?: EntryResolvers<ContextType>
  Query?: QueryResolvers<ContextType>
}

/**
 * @deprecated
 * Use "Resolvers" root object instead. If you wish to get "IResolvers", add "typesPrefix: I" to your config.
 */
export type IResolvers<ContextType = Context> = Resolvers<ContextType>
