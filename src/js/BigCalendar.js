'use strict';

Object.defineProperty(exports, "__esModule", {
    value: true
});

var _extends = Object.assign || function (target) {
    for (var i = 1; i < arguments.length; i++) {
        var source = arguments[i];
        for (var key in source) {
            if (Object.prototype.hasOwnProperty.call(source, key)) {
                target[key] = source[key];
            }
        }
    }
    return target;
};

var _createClass = function () {
    function defineProperties(target, props) {
        for (var i = 0; i < props.length; i++) {
            var descriptor = props[i];
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

var _react = require('react');

var _reactBigCalendar = require('react-big-calendar');

var _reactBigCalendar2 = _interopRequireDefault(_reactBigCalendar);

var _moment = require('moment');

var _moment2 = _interopRequireDefault(_moment);

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

_reactBigCalendar2.default.momentLocalizer(_moment2.default);

var allViews = ['day', 'week'];

var MyEvent = function (_Component) {
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

var eventPropGetter = function eventPropGetter(event, start, end, isSelected) {
    return {
        style: {backgroundColor: event.color}
    };
};

var components = {
    event: MyEvent
};

var messages = {
    allDay: ''
};

var Calendar = function (_Component2) {
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
