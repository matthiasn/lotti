import {ActionType} from 'typesafe-actions';
import * as appActions from './appActions';
import * as usersActions from './usersActions';

export type AppAction = ActionType<typeof appActions>;
export type UsersAction = ActionType<typeof usersActions>;

export type RootAction = AppAction | UsersAction;
