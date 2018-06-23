"use strict";
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
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (Object.hasOwnProperty.call(mod, k)) result[k] = mod[k];
    result["default"] = mod;
    return result;
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
var react_1 = __importStar(require("react"));
var react_navigation_1 = require("react-navigation");
var react_native_1 = require("react-native");
var react_native_settings_list_1 = __importDefault(require("react-native-settings-list"));
var FontAwesome_1 = __importDefault(require("react-native-vector-icons/FontAwesome"));
var rn_apple_healthkit_1 = __importDefault(require("rn-apple-healthkit"));
var RNFS = require('react-native-fs');
var bg = "#141414";
var itemBg = "#272727";
var textColor = "#D8D8D8";
var healthOptions = {
    permissions: {
        read: [
            "Height", "Weight", "StepCount",
            "FlightsClimbed",
            "BloodPressureDiastolic", "BloodPressureSystolic", "HeartRate",
            "DistanceWalkingRunning", "SleepAnalysis", "RespiratoryRate",
            "DateOfBirth", "BodyMassIndex", "ActiveEnergyBurned"
        ]
    }
};
function readSteps(that) {
    rn_apple_healthkit_1.default.initHealthKit(healthOptions, function (err, results) {
        if (err) {
            console.log("error initializing HealthKit: ", err);
            react_native_1.Alert.alert(err);
            return;
        }
        rn_apple_healthkit_1.default.getStepCount({ date: (new Date()).toISOString() }, function (err, results) {
            console.log(results);
            if (err) {
                return;
            }
            var steps = results.value;
            that.setState(function (prevState) {
                prevState.stepsToday = steps;
                return prevState;
            });
            console.log("steps today", steps);
        });
        var options = {
            startDate: (new Date(2016, 0, 1)).toISOString(),
            endDate: (new Date()).toISOString() // optional; default now
        };
        rn_apple_healthkit_1.default.getDailyStepCountSamples(options, function (err, results) {
            if (err) {
                console.error(err);
                return;
            }
            that.setState(function (prevState) {
                prevState.steps = results;
                return prevState;
            });
            var serialized = JSON.stringify(results);
            var path = RNFS.DocumentDirectoryPath + '/steps.json';
            RNFS.writeFile(path, serialized, 'utf8')
                .then(function (success) {
                console.log('FILE WRITTEN!');
            })
                .catch(function (err) {
                console.log(err.message);
            });
        });
    });
}
var settingsIcon = function (name) { return (react_1.default.createElement(FontAwesome_1.default, { name: name, size: 20, style: { paddingTop: 14, paddingLeft: 14 }, color: textColor })); };
var Settings = /** @class */ (function (_super) {
    __extends(Settings, _super);
    function Settings(props) {
        var _this = _super.call(this, props) || this;
        _this.state = {
            switchValue: false,
            stepsToday: 0,
            steps: [],
            toggleAuthView: function () { }
        };
        _this.onValueChange = _this.onValueChange.bind(_this);
        return _this;
    }
    Settings.prototype.componentDidMount = function () {
        this.props.navigation.addListener('didFocus', function () {
            react_native_1.StatusBar.setBarStyle('light-content');
        });
    };
    Settings.prototype.render = function () {
        var _this = this;
        return (react_1.default.createElement(react_native_1.View, { style: { backgroundColor: bg, flex: 1, width: "100%" } },
            react_1.default.createElement(react_native_1.View, { style: { backgroundColor: bg } },
                react_1.default.createElement(react_native_1.Text, { style: { alignSelf: 'center', marginTop: 40, marginBottom: 10, fontWeight: 'bold', color: "white", fontSize: 16 } }, "meo")),
            react_1.default.createElement(react_native_1.View, { style: { backgroundColor: bg, flex: 1 } },
                react_1.default.createElement(react_native_settings_list_1.default, { borderColor: bg, defaultItemSize: 50 },
                    react_1.default.createElement(react_native_settings_list_1.default.Item, { backgroundColor: itemBg, titleStyle: styles.titleStyle, icon: settingsIcon("moon-o"), hasSwitch: true, 
                        //switchState={this.state.switchValue}
                        switchOnValueChange: this.onValueChange, hasNavArrow: false, title: 'Dark Theme', onPress: function () { return _this.props.navigation.navigate('Home'); } }),
                    react_1.default.createElement(react_native_settings_list_1.default.Item, { backgroundColor: itemBg, titleStyle: styles.titleStyle, icon: settingsIcon("database"), title: 'Database', titleInfo: '91345', titleInfoStyle: styles.titleInfoStyle, onPress: function () { return react_native_1.Alert.alert('Route to Database Page'); } }),
                    react_1.default.createElement(react_native_settings_list_1.default.Item, { backgroundColor: itemBg, titleStyle: styles.titleStyle, icon: settingsIcon("address-book"), title: 'Contacts', titleInfoStyle: styles.titleInfoStyle, onPress: function () { return react_native_1.Alert.alert('Route to Contacts Page'); } }),
                    react_1.default.createElement(react_native_settings_list_1.default.Item, { backgroundColor: itemBg, titleStyle: styles.titleStyle, icon: settingsIcon("heartbeat"), title: 'Health Data', titleInfo: this.state.stepsToday.toString(), titleInfoStyle: styles.titleInfoStyle, onPress: function () {
                            _this.props.navigation.navigate("Health");
                        } }),
                    react_1.default.createElement(react_native_settings_list_1.default.Item, { backgroundColor: itemBg, titleStyle: styles.titleStyle, icon: settingsIcon("font"), title: 'Style', titleInfoStyle: styles.titleInfoStyle, onPress: function () { return react_native_1.Alert.alert('Route to Style Page'); } }),
                    react_1.default.createElement(react_native_settings_list_1.default.Item, { backgroundColor: itemBg, titleStyle: styles.titleStyle, icon: settingsIcon("shield"), title: 'Security', onPress: function () { return react_native_1.Alert.alert('Route To Security Page'); } }),
                    react_1.default.createElement(react_native_settings_list_1.default.Item, { backgroundColor: itemBg, titleStyle: styles.titleStyle, icon: settingsIcon("eye"), title: 'Dev', titleInfoStyle: styles.titleInfoStyle, onPress: function () { return react_native_1.Alert.alert('Route To Dev Page'); } }),
                    react_1.default.createElement(react_native_settings_list_1.default.Header, { headerStyle: { marginTop: 15 } }),
                    react_1.default.createElement(react_native_settings_list_1.default.Item, { backgroundColor: itemBg, titleStyle: styles.titleStyle, icon: settingsIcon("warning"), title: 'Notifications', onPress: function () { return react_native_1.Alert.alert('Route To Notifications Page'); } })))));
    };
    Settings.prototype.toggleAuthView = function () {
        //this.setState({toggleAuthView: !this.state.toggleAuthView});
    };
    Settings.prototype.onValueChange = function (value) {
        this.setState({ switchValue: value });
    };
    return Settings;
}(react_1.Component));
exports.default = Settings;
var styles = react_native_1.StyleSheet.create({
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
var HealthModal = /** @class */ (function (_super) {
    __extends(HealthModal, _super);
    function HealthModal() {
        var _this = _super !== null && _super.apply(this, arguments) || this;
        _this.state = {
            stepsToday: 0,
            steps: []
        };
        return _this;
    }
    HealthModal.prototype.componentDidMount = function () {
        readSteps(this);
        this.props.navigation.addListener('didFocus', function () {
            react_native_1.StatusBar.setBarStyle('dark-content');
        });
    };
    HealthModal.prototype.render = function () {
        var _this = this;
        var listItems = this.state.steps.map(function (_a) {
            var value = _a.value, startDate = _a.startDate;
            return react_1.default.createElement(react_native_1.Text, { style: { fontFamily: "Courier", fontSize: 22 }, key: startDate },
                " ",
                startDate.substring(0, 10),
                ": \u00A0\u00A0\u00A0",
                react_1.default.createElement(react_native_1.Text, { style: { fontWeight: "bold" } }, parseInt(value)));
        });
        return (react_1.default.createElement(react_native_1.ScrollView, { style: { marginTop: 100 } },
            react_1.default.createElement(react_native_1.View, { style: { flex: 1, alignItems: 'center', justifyContent: 'center' } },
                react_1.default.createElement(react_native_1.Text, { style: { fontSize: 30, marginBottom: 10 } },
                    this.state.stepsToday,
                    " steps today so far"),
                react_1.default.createElement(react_native_1.Button, { onPress: function () { return _this.props.navigation.goBack(); }, title: "Dismiss" })),
            react_1.default.createElement(react_native_1.View, { style: { marginLeft: 40, marginTop: 40 } }, listItems)));
    };
    return HealthModal;
}(react_1.default.Component));
exports.SettingsStack = react_navigation_1.createStackNavigator({
    Main: {
        screen: Settings,
    },
    Health: {
        screen: HealthModal,
    },
}, {
    mode: 'modal',
    headerMode: 'none',
    transitionConfig: function () { return ({
        transitionSpec: {
            duration: 0
        },
    }); },
});
