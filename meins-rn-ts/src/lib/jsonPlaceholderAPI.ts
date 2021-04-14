import {User} from 'src/types';

export default class JSONPlacholderAPI {
  static apiEntry = 'https://jsonplaceholder.typicode.com';
  static usersNamespace = 'users';

  static async fetchUser(userID: string): Promise<User> {
    const url = `${JSONPlacholderAPI.apiEntry}/${JSONPlacholderAPI.usersNamespace}/${userID}`;
    const res = await fetch(url);
    const data = await res.json();
    const {id, email, name, phone} = data;
    const user: User = {id, email, name, phone};
    return user;
  }
}
