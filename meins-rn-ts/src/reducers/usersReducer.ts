'use strict';
import {fetchUserAsync, setUser} from 'src/actions/usersActions';
import {User} from 'src/types';
import {createReducer} from 'typesafe-actions';
import {UsersAction} from 'src/actions/actionTypes';

export interface UsersState {
  user?: User;
}

const initialState: UsersState = {};

const usersReducer = createReducer<UsersState, UsersAction>(initialState)
  .handleAction(fetchUserAsync.success, (state, action) => ({...state, user: action.payload}))
  .handleAction(setUser, (state, action) => ({...state, user: action.payload}));

export default usersReducer;
