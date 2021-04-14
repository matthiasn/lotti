import {all} from 'redux-saga/effects';
import users from './usersSagas';

export default function* root() {
  yield all([users()]);
}
