'use strict';

Object.defineProperty(exports, "__esModule", {
    value: true
});

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

var _react2 = _interopRequireDefault(_react);

var _draftJsPluginsEditor = require('draft-js-plugins-editor');

var _draftJsPluginsEditor2 = _interopRequireDefault(_draftJsPluginsEditor);

var _draftJsMentionPlugin = require('draft-js-mention-plugin');

var _draftJsMentionPlugin2 = _interopRequireDefault(_draftJsMentionPlugin);

var _immutable = require('immutable');

var _draftJs = require('draft-js');

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
} // eslint-disable-line import/no-unresolved
// eslint-disable-line import/no-unresolved


var StyleButton = function (_Component) {
    _inherits(StyleButton, _Component);

    function StyleButton() {
        _classCallCheck(this, StyleButton);

        var _this = _possibleConstructorReturn(this, (StyleButton.__proto__ || Object.getPrototypeOf(StyleButton)).call(this));

        _this.onToggle = function (e) {
            e.preventDefault();
            _this.props.onToggle(_this.props.style);
        };
        return _this;
    }

    _createClass(StyleButton, [{
        key: 'render',
        value: function render() {
            var className = 'fa ' + this.props.icon;
            if (this.props.active) {
                className += ' RichEditor-activeButton';
            }
            return _react2.default.createElement(
                'span',
                {
                    className: className,
                    onMouseDown: this.onToggle
                },
                this.props.label
            );
        }
    }]);

    return StyleButton;
}(_react.Component);

var INLINE_STYLES = [{
    label: 'Bold',
    style: 'BOLD',
    icon: 'fa-bold fa-wide'
}, {
    label: 'Italic',
    style: 'ITALIC',
    icon: 'fa-italic fa-wide'
}, {
    label: 'Underline',
    style: 'UNDERLINE',
    icon: 'fa-underline fa-wide'
}, {
    label: 'Monospace',
    style: 'CODE',
    icon: 'fa-code fa-wide'
}, {label: 'strike', style: 'STRIKETHROUGH', icon: 'fa-strikethrough fa-wide'}];

var BLOCK_TYPES = [{
    style: 'header-one',
    icon: 'fa-header'
}, {style: 'header-two', icon: 'fa-header header-2'}, {
    style: 'header-three',
    icon: 'fa-header header-3'
}, {
    style: 'unordered-list-item',
    icon: 'fa-list-ul fa-wide'
}, {
    style: 'ordered-list-item',
    icon: 'fa-list-ol fa-wide'
}, {style: 'code-block', icon: 'fa-code'}];

var StyleControls = function StyleControls(props) {
    var editorState = props.editorState,
        state = props.state,
        show = props.show;

    var selection = editorState.getSelection();
    var blockType = editorState.getCurrentContent().getBlockForKey(selection.getStartKey()).getType();
    var currentStyle = editorState.getCurrentInlineStyle();

    if (props.show) {
        return _react2.default.createElement(
            'div',
            {className: 'RichEditor-controls edit-menu'},
            INLINE_STYLES.map(function (type) {
                return _react2.default.createElement(StyleButton, {
                    key: type.style,
                    active: currentStyle.has(type.style),
                    icon: type.icon,
                    onToggle: props.onToggleInline,
                    style: type.style
                });
            }),
            BLOCK_TYPES.map(function (type) {
                return _react2.default.createElement(StyleButton, {
                    key: type.style,
                    active: type.style === blockType,
                    icon: type.icon,
                    onToggle: props.onToggleBlockType,
                    style: type.style
                });
            })
        );
    }
    return null;
};

exports.default = StyleControls;
