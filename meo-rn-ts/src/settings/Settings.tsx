import React, { Component } from 'react';
import { createStackNavigator } from 'react-navigation'
import { StyleSheet, Text, View, StatusBar, Alert } from 'react-native';
import SettingsList from 'react-native-settings-list';
import Icon from 'react-native-vector-icons/FontAwesome';
import HealthModal from './Health'

const bg = "#141414";
const itemBg = "#272727";
const textColor = "#D8D8D8";

const settingsIcon = (name) => (
  <Icon name={name} size={20} style={{ paddingTop: 14, paddingLeft: 14 }} color={textColor} />
)

interface State {
  switchValue: Boolean;
}

interface Props {
  navigation: {
    addListener: Function,
    navigate: Function,
    goBack: Function
  };
}

export default class Settings extends Component<Props, State> {
  public state: State = {
    switchValue: false
  };
  constructor(props: any) {
    super(props);
    this.onValueChange = this.onValueChange.bind(this);
  }
  componentDidMount() {
    this.props.navigation.addListener('didFocus', () => {
      StatusBar.setBarStyle('light-content');
    });
  }
  render() {
    return (
      <View style={{ backgroundColor: bg, flex: 1, width: "100%" }}>
        <View style={{ backgroundColor: bg }}>
          <Text style={{ alignSelf: 'center', marginTop: 40, marginBottom: 10, fontWeight: 'bold', color: "white", fontSize: 16 }}>meo</Text>
        </View>
        <View style={{ backgroundColor: bg, flex: 1 }}>
          <SettingsList borderColor={bg} defaultItemSize={50}>
            <SettingsList.Item
              backgroundColor={itemBg}
              titleStyle={styles.titleStyle}
              icon={settingsIcon("moon-o")}
              hasSwitch={true}
              //switchState={this.state.switchValue}
              switchOnValueChange={this.onValueChange}
              hasNavArrow={false}
              title='Dark Theme'
              onPress={() => this.props.navigation.navigate('Home')}
            />
            <SettingsList.Item
              backgroundColor={itemBg}
              titleStyle={styles.titleStyle}
              icon={settingsIcon("database")}
              title='Database'
              titleInfo='91345'
              titleInfoStyle={styles.titleInfoStyle}
              onPress={() => Alert.alert('Route to Database Page')}
            />
            <SettingsList.Item
              backgroundColor={itemBg}
              titleStyle={styles.titleStyle}
              icon={settingsIcon("address-book")}
              title='Contacts'
              titleInfoStyle={styles.titleInfoStyle}
              onPress={() => Alert.alert('Route to Contacts Page')}
            />
            <SettingsList.Item
              backgroundColor={itemBg}
              titleStyle={styles.titleStyle}
              icon={settingsIcon("heartbeat")}
              title='Health Data'
              titleInfoStyle={styles.titleInfoStyle}
              onPress={() => {
                this.props.navigation.navigate("Health")
              }}
            />
            <SettingsList.Item
              backgroundColor={itemBg}
              titleStyle={styles.titleStyle}
              icon={settingsIcon("font")}
              title='Style'
              titleInfoStyle={styles.titleInfoStyle}
              onPress={() => Alert.alert('Route to Style Page')}
            />
            <SettingsList.Item
              backgroundColor={itemBg}
              titleStyle={styles.titleStyle}
              icon={settingsIcon("shield")}
              title='Security'
              onPress={() => Alert.alert('Route To Security Page')}
            />
            <SettingsList.Item
              backgroundColor={itemBg}
              titleStyle={styles.titleStyle}
              icon={settingsIcon("eye")}
              title='Dev'
              titleInfoStyle={styles.titleInfoStyle}
              onPress={() => Alert.alert('Route To Dev Page')}
            />
            <SettingsList.Header headerStyle={{ marginTop: 15 }} />
            <SettingsList.Item
              backgroundColor={itemBg}
              titleStyle={styles.titleStyle}
              icon={settingsIcon("warning")}
              title='Notifications'
              onPress={() => Alert.alert('Route To Notifications Page')}
            />
          </SettingsList>
        </View>
      </View>
    );
  }
  onValueChange() {
    this.setState({ switchValue: !this.state.switchValue });
  }
}

const styles = StyleSheet.create({
  imageStyle: {
    marginLeft: 15,
    alignSelf: 'center',
    height: 30,
    width: 30
  },
  titleInfoStyle: {
    fontSize: 12,
    color: '#8e8e93'
  },
  titleStyle: {
    color: textColor,
    fontSize: 16
  }
});

export const SettingsStack = createStackNavigator(
  {
    Main: {
      screen: Settings,
    },
    Health: {
      screen: HealthModal,
    },
  },
  {
    mode: 'modal',
    headerMode: 'none',
    transitionConfig: () => ({
      transitionSpec: {
        duration: 0
      },
    }),
  }
);
