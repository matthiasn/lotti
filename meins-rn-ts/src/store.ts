import AsyncStorage from '@react-native-community/async-storage';
import appReducer, {AppReducerState} from 'src/reducers/appReducer';
import usersReducer, {UsersState} from 'src/reducers/usersReducer';
import sagas from 'src/sagas/';
import {
  applyMiddleware,
  combineReducers,
  compose,
  createStore,
  Dispatch,
  MiddlewareAPI,
} from 'redux';
import {PersistConfig, persistReducer, persistStore} from 'redux-persist';
import createSagaMiddleware from 'redux-saga';
import {RootAction} from 'src/actions/actionTypes';

/*
 *--------------------------------------------------*
 * Persist config documentation
 * https://github.com/rt2zz/redux-persist/blob/master/src/types.js#L13-L27
 *--------------------------------------------------*
 */

const appPersistConfig: PersistConfig<AppReducerState, unknown, unknown, unknown> = {
  storage: AsyncStorage,
  key: 'app',
};

const usersPersistConfig: PersistConfig<UsersState, unknown, unknown, unknown> = {
  storage: AsyncStorage,
  key: 'users',
};

export const reducers = {
  app: persistReducer(appPersistConfig, appReducer),
  users: persistReducer(usersPersistConfig, usersReducer),
};

export const rootReducer = combineReducers(reducers);
export type RootState = ReturnType<typeof rootReducer>;

const appMiddleware = (_store: MiddlewareAPI) => (next: Dispatch) => (action: RootAction) => {
  //   var state = store.getState()
  //   switch (action.type) {
  //     case actions.ADD_TASK:
  //       *do something*
  //       break;
  //   }
  next(action);
};

const sagaMiddleware = createSagaMiddleware();

const middlewares = [sagaMiddleware, appMiddleware];
const enhancers = [applyMiddleware(...middlewares)];

export const store = createStore(rootReducer, compose(...enhancers));

sagaMiddleware.run(sagas);

export const persistor = persistStore(store);

/*
 *--------------------------------------------------*
 * Reset persist store: persistor.purge()
 *--------------------------------------------------*
 */
