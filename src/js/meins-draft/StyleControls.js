'use strict';

Object.defineProperty(exports, "__esModule", {
    value: true
});

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
let _react2 = _interopRequireDefault(_react);

let _draftJsPluginsEditor = require('draft-js-plugins-editor');
let _draftJsPluginsEditor2 = _interopRequireDefault(_draftJsPluginsEditor);

let _draftJsMentionPlugin = require('draft-js-mention-plugin');
let _draftJsMentionPlugin2 = _interopRequireDefault(_draftJsMentionPlugin);

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

let StyleButton = function (_Component) {
    _inherits(StyleButton, _Component);

    function StyleButton() {
        _classCallCheck(this, StyleButton);

        let _this = _possibleConstructorReturn(this, (StyleButton.__proto__ || Object.getPrototypeOf(StyleButton)).call(this));

        _this.onToggle = function (e) {
            e.preventDefault();
            _this.props.onToggle(_this.props.style);
        };
        return _this;
    }

    _createClass(StyleButton, [{
        key: 'render',
        value: function render() {
            let className = 'fa far ' + this.props.icon;
            if (this.props.active) {
                className += ' active-button';
            }
            return _react2.default.createElement(
                'i',
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

let INLINE_STYLES = [{
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

let BLOCK_TYPES = [{
    style: 'header-one',
    icon: 'fa-heading'
}, {style: 'header-two',
    icon: 'fa-heading header-2'}, {
    style: 'header-three',
    icon: 'fa-heading header-3'
}, {
    style: 'unordered-list-item',
    icon: 'fa-list-ul fa-wide'
}, {
    style: 'ordered-list-item',
    icon: 'fa-list-ol fa-wide'
}];

let StyleControls = function StyleControls(props) {
    let editorState = props.editorState,
        state = props.state,
        show = props.show;

    let selection = editorState.getSelection();
    let blockType = editorState.getCurrentContent().getBlockForKey(selection.getStartKey()).getType();
    let currentStyle = editorState.getCurrentInlineStyle();

    if (props.show) {
        return _react2.default.createElement(
            'div',
            {className: 'RichEditor-controls edit-menu'},

            _react2.default.createElement(StyleButton, {
                icon: "fa-save fa-wide",
                onToggle: props.save,
                style: "menu-save"
            }),

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
