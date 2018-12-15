'use strict';

Object.defineProperty(exports, "__esModule", {
    value: true
});

let _extends = Object.assign || function (target) {
    for (let i = 1; i < arguments.length; i++) {
        let source = arguments[i];
        for (let key in source) {
            if (Object.prototype.hasOwnProperty.call(source, key)) {
                target[key] = source[key];
            }
        }
    }
    return target;
};

let _createClass = function () {
    function defineProperties(target, props) {
        for (let i = 0; i < props.length; i++) {
            let descriptor = props[i];
            descriptor.enumerable = descriptor.enumerable || false;
            descriptor.configurable = true;
            if ("value" in descriptor) descriptor.writable = true;
            Object.defineProperty(target, descriptor.key, descriptor);
        }
    }

    return function (Constructor, protoProps, staticProps) {
        if (protoProps) defineProperties(Constructor.prototype, protoProps);
        if (staticProps) defineProperties(Constructor, staticProps);
        return Constructor;
    };
}();

let _react = require('react');

let _reactBigCalendar = require('react-big-calendar');
let _reactBigCalendar2 = _interopRequireDefault(_reactBigCalendar);

let _moment = require('moment/min/moment-with-locales');
let _moment2 = _interopRequireDefault(_moment);

function _interopRequireDefault(obj) {
    return obj && obj.__esModule ? obj : {default: obj};
}

function _classCallCheck(instance, Constructor) {
    if (!(instance instanceof Constructor)) {
        throw new TypeError("Cannot call a class as a function");
    }
}

function _possibleConstructorReturn(self, call) {
    if (!self) {
        throw new ReferenceError("this hasn't been initialised - super() hasn't been called");
    }
    return call && (typeof call === "object" || typeof call === "function") ? call : self;
}

function _inherits(subClass, superClass) {
    if (typeof superClass !== "function" && superClass !== null) {
        throw new TypeError("Super expression must either be null or a function, not " + typeof superClass);
    }
    subClass.prototype = Object.create(superClass && superClass.prototype, {
        constructor: {
            value: subClass,
            enumerable: false,
            writable: true,
            configurable: true
        }
    });
    if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass;
}

let globalize = require("globalize");
globalize.load( require( "cldr-data" ).entireSupplemental() );
globalize.load( require( "cldr-data" ).entireMainFor( "en", "de", "fr", "es" ) );
globalize.loadTimeZone( require( "iana-tz-data" ) );
globalize.locale( "de" );

const localizer = _reactBigCalendar2.default.globalizeLocalizer(globalize)

let allViews = ['day', 'week'];

let MyEvent = function (_Component) {
    _inherits(MyEvent, _Component);

    function MyEvent() {
        _classCallCheck(this, MyEvent);

        return _possibleConstructorReturn(this, (MyEvent.__proto__ || Object.getPrototypeOf(MyEvent)).apply(this, arguments));
    }

    _createClass(MyEvent, [{
        key: 'render',
        value: function render() {
            return React.createElement(
                'div',
                {onClick: this.props.event.click},
                this.props.event.title
            );
        }
    }]);

    return MyEvent;
}(_react.Component);

let eventPropGetter = function eventPropGetter(event, start, end, isSelected) {
    return {
        style: {backgroundColor: event.color}
    };
};

let components = {
    event: MyEvent
};

let messages = {
    allDay: ''
};

let Calendar = function (_Component2) {
    _inherits(Calendar, _Component2);

    function Calendar() {
        _classCallCheck(this, Calendar);

        return _possibleConstructorReturn(this, (Calendar.__proto__ || Object.getPrototypeOf(Calendar)).apply(this, arguments));
    }

    _createClass(Calendar, [{
        key: 'render',
        value: function render() {
            return React.createElement(_reactBigCalendar2.default, _extends({}, this.props, {
                events: this.props.events,
                views: allViews,
                defaultView: 'day',
                toolbar: false,
                localizer: localizer,
                components: components,
                messages: messages,
                eventPropGetter: eventPropGetter,
                defaultDate: this.props.defaultDate,
                scrollToTime: this.props.scrollToDate
            }));
        }
    }]);

    return Calendar;
}(_react.Component);

exports.default = Calendar;
