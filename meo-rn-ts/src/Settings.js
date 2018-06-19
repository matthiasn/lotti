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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
var react_1 = __importDefault(require("react"));
var react_2 = require("react");
var react_native_1 = require("react-native");
var react_native_settings_list_1 = __importDefault(require("react-native-settings-list"));
var FontAwesome_1 = __importDefault(require("react-native-vector-icons/FontAwesome"));
var rn_apple_healthkit_1 = __importDefault(require("rn-apple-healthkit"));
var RNFS = require('react-native-fs');
var bg = "#141414";
var itemBg = "#272727";
var textColor = "#D8D8D8";
var stepsToday = "0";
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
function readSteps() {
    rn_apple_healthkit_1.default.initHealthKit(healthOptions, function (err, results) {
        if (err) {
            console.log("error initializing HealthKit: ", err);
            react_native_1.Alert.alert(err);
            return;
        }
        rn_apple_healthkit_1.default.getStepCount({ date: (new Date(2018, 5, 18)).toISOString() }, function (err, results) {
            console.log(results);
            if (err) {
                return;
            }
            stepsToday = results.value.toString();
            console.log("steps today", stepsToday);
        });
        var options = {
            startDate: (new Date(2017, 1, 1)).toISOString(),
            endDate: (new Date()).toISOString() // optional; default now
        };
        rn_apple_healthkit_1.default.getDailyStepCountSamples(options, function (err, results) {
            if (err) {
                console.error(err);
                return;
            }
            var serialized = JSON.stringify(results);
            var path = RNFS.DocumentDirectoryPath + '/steps.json';
            RNFS.writeFile(path, serialized, 'utf8')
                .then(function (success) {
                console.log('FILE WRITTEN!');
                react_native_1.Alert.alert("steps written");
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
        _this.onValueChange = _this.onValueChange.bind(_this);
        _this.state = {
            switchValue: false,
            loggedIn: false,
            toggleAuthView: function () { }
        };
        return _this;
    }
    Settings.prototype.render = function () {
        return (react_1.default.createElement(react_native_1.View, { style: { backgroundColor: bg, flex: 1, width: "100%" } },
            react_1.default.createElement(react_native_1.View, { style: { backgroundColor: bg } },
                react_1.default.createElement(react_native_1.Text, { style: { alignSelf: 'center', marginTop: 40, marginBottom: 10, fontWeight: 'bold', color: "white", fontSize: 16 } }, "meo")),
            react_1.default.createElement(react_native_1.View, { style: { backgroundColor: bg, flex: 1 } },
                react_1.default.createElement(react_native_settings_list_1.default, { borderColor: bg, defaultItemSize: 50 },
                    react_1.default.createElement(react_native_settings_list_1.default.Item, { backgroundColor: itemBg, titleStyle: styles.titleStyle, icon: settingsIcon("moon-o"), hasSwitch: true, 
                        //switchState={this.state.switchValue}
                        switchOnValueChange: this.onValueChange, hasNavArrow: false, title: 'Dark Theme' }),
                    react_1.default.createElement(react_native_settings_list_1.default.Item, { backgroundColor: itemBg, titleStyle: styles.titleStyle, icon: settingsIcon("database"), title: 'Database', titleInfo: '91345', titleInfoStyle: styles.titleInfoStyle, onPress: function () { return react_native_1.Alert.alert('Route to Database Page'); } }),
                    react_1.default.createElement(react_native_settings_list_1.default.Item, { backgroundColor: itemBg, titleStyle: styles.titleStyle, icon: settingsIcon("address-book"), title: 'Contacts', titleInfoStyle: styles.titleInfoStyle, onPress: function () { return react_native_1.Alert.alert('Route to Contacts Page'); } }),
                    react_1.default.createElement(react_native_settings_list_1.default.Item, { backgroundColor: itemBg, titleStyle: styles.titleStyle, titleInfo: stepsToday.toString(), icon: settingsIcon("heartbeat"), title: 'Health Data', titleInfoStyle: styles.titleInfoStyle, onPress: function () { return readSteps(); } }),
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
}(react_2.Component));
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
