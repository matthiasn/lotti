import { createBottomTabNavigator } from '@react-navigation/bottom-tabs'
import * as React from 'react'
import { useTranslation } from 'react-i18next'
import RNBootSplash from 'react-native-bootsplash'
import Icon from 'react-native-vector-icons/FontAwesome'
import RecordTab from 'src/containers/RecordTab'
import Settings from 'src/containers/Settings'
import { sleep } from './utils/async'
import EntriesTab from 'src/containers/EntriesTab'
import ListenTab from 'src/containers/ListenTab'

export type AppTabParamList = {
  Home: undefined
  Settings: { userID?: string }
}

const Tab = createBottomTabNavigator()

const App = () => {
  const init = async () => {
    await sleep(1000)
    // …do multiple async tasks
  }

  React.useEffect(() => {
    init().finally(() => {
      RNBootSplash.hide({ duration: 250 }) // fade animation
    })
  }, [])

  const { t } = useTranslation()
  return (
    <Tab.Navigator initialRouteName="home">
      <Tab.Screen
        name="record"
        component={RecordTab}
        options={{
          tabBarLabel: t('recordTab'),
          tabBarIcon: ({ color, size }) => <Icon name={'microphone'} size={size} color={color} />,
        }}
      />
      <Tab.Screen
        name="entries"
        component={EntriesTab}
        options={{
          tabBarLabel: t('entriesTab'),
          tabBarIcon: ({ color, size }) => <Icon name={'list'} size={size} color={color} />,
        }}
      />
      <Tab.Screen
        name="listen"
        component={ListenTab}
        options={{
          tabBarLabel: t('listenTab'),
          tabBarIcon: ({ color, size }) => (
            <Icon name={'assistive-listening-systems'} size={size} color={color} />
          ),
        }}
      />
      <Tab.Screen
        name="settings"
        component={Settings}
        options={{
          tabBarLabel: t('settings'),
          tabBarIcon: ({ color, size }) => <Icon name={'cog'} size={size} color={color} />,
        }}
      />
    </Tab.Navigator>
  )
}

export default App
