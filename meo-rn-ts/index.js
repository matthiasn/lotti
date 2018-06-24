import { AppRegistry } from 'react-native';
import App from './out/src/App';
AppRegistry.registerComponent('meoTs', () => App);

import { YellowBox } from 'react-native'
YellowBox.ignoreWarnings(['Warning: isMounted(...) is deprecated', 'Module RCTImageLoader'])
