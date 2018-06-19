"use strict";
/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 */
var __extends = (this && this.__extends) || (function () {
    var extendStatics = Object.setPrototypeOf ||
        ({ __proto__: [] } instanceof Array && function (d, b) { d.__proto__ = b; }) ||
        function (d, b) { for (var p in b) if (b.hasOwnProperty(p)) d[p] = b[p]; };
    return function (d, b) {
        extendStatics(d, b);
        function __() { this.constructor = d; }
        d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
var react_1 = __importDefault(require("react"));
var Ionicons_1 = __importDefault(require("react-native-vector-icons/Ionicons"));
var react_native_1 = require("react-native");
var Settings_1 = __importDefault(require("./src/Settings"));
var react_navigation_1 = require("react-navigation");
var instructions = react_native_1.Platform.select({
    ios: 'Hello Matthias, press Cmd+R to reload,\n' +
        'Cmd+D or shake for dev menu',
    android: 'Double tap R on your keyboard to reload,\n' +
        'Shake or press menu button for dev menu',
});
var styles = react_native_1.StyleSheet.create({
    container: {
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center',
        backgroundColor: '#F5FCFF',
    },
    welcome: {
        fontSize: 20,
        textAlign: 'center',
        margin: 10,
    },
    instructions: {
        textAlign: 'center',
        color: '#333333',
        marginBottom: 5,
    },
});
var HomeScreen = /** @class */ (function (_super) {
    __extends(HomeScreen, _super);
    function HomeScreen() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    HomeScreen.prototype.render = function () {
        return (react_1.default.createElement(react_native_1.View, { style: { flex: 1, alignItems: 'center', justifyContent: 'center' } },
            react_1.default.createElement(react_native_1.Text, null, "meo"),
            react_1.default.createElement(react_native_1.Text, null, instructions)));
    };
    return HomeScreen;
}(react_1.default.Component));
var bg = "black";
var RootStack = react_navigation_1.createBottomTabNavigator({
    Home: HomeScreen,
    Journal: HomeScreen,
    Add: HomeScreen,
    Photos: HomeScreen,
    Settings: Settings_1.default,
}, {
    navigationOptions: function (_a) {
        var navigation = _a.navigation;
        return ({
            tabBarIcon: function (_a) {
                var focused = _a.focused, tintColor = _a.tintColor;
                var routeName = navigation.state.routeName;
                var iconName;
                if (routeName === 'Home') {
                    iconName = "ios-information-circle" + (focused ? '' : '-outline');
                }
                else if (routeName === 'Journal') {
                    iconName = "ios-search" + (focused ? '' : '-outline');
                }
                else if (routeName === 'Add') {
                    iconName = "ios-add-circle" + (focused ? '' : '-outline');
                }
                else if (routeName === 'Photos') {
                    iconName = "ios-images" + (focused ? '' : '-outline');
                }
                else if (routeName === 'Settings') {
                    iconName = "ios-options" + (focused ? '' : '-outline');
                }
                // You can return any component that you like here! We usually use an
                // icon component from react-native-vector-icons
                return react_1.default.createElement(Ionicons_1.default, { name: iconName, size: 24, color: tintColor });
            },
        });
    },
    tabBarOptions: {
        activeTintColor: "#0078e7",
        activeBackgroundColor: bg,
        inactiveBackgroundColor: bg,
        style: { backgroundColor: bg },
        tabStyle: { margin: 0 },
        inactiveTintColor: "#AAA",
        showLabel: false
    }
});
var App = /** @class */ (function (_super) {
    __extends(App, _super);
    function App() {
        return _super !== null && _super.apply(this, arguments) || this;
    }
    App.prototype.render = function () {
        return react_1.default.createElement(RootStack, null);
    };
    return App;
}(react_1.default.Component));
exports.default = App;
