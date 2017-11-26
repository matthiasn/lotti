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
} // eslint-disable-line import/no-unresolved
// eslint-disable-line import/no-unresolved


let SearchFieldEditor = function (_Component) {
    _inherits(SearchFieldEditor, _Component);

    function SearchFieldEditor(props) {
        _classCallCheck(this, SearchFieldEditor);

        let _this = _possibleConstructorReturn(this, (SearchFieldEditor.__proto__ || Object.getPrototypeOf(SearchFieldEditor)).call(this, props));

        _this.state = {};

        _this.onSearchChange = function (_ref) {
            let value = _ref.value;

            let mentions = _this.props.mentions;
            _this.setState({
                mentionSuggestions: (0, _draftJsMentionPlugin.defaultSuggestionsFilter)(value, mentions)
            });
        };

        _this.onSearchChange2 = function (_ref2) {
            let value = _ref2.value;

            let hashtags = _this.props.hashtags;
            _this.setState({
                hashtagSuggestions: (0, _draftJsMentionPlugin.defaultSuggestionsFilter)(value, hashtags)
            });
        };

        _this.onSearchChangeStories = function (_ref3) {
            let value = _ref3.value;

            let stories = _this.props.stories;
            _this.setState({
                storySuggestions: (0, _draftJsMentionPlugin.defaultSuggestionsFilter)(value, stories)
            });
        };

        _this.focus = function () {
            _this.editor.focus();
        };

        _this.onAddMention = function () {
            // get the mention object selected
        };

        _this.onAddStory = function (story) {
        };

        _this.state.editorState = props.editorState;

        let hashtagPlugin = (0, _draftJsMentionPlugin2.default)({
            mentionTrigger: "#"
        });

        let mentionPlugin = (0, _draftJsMentionPlugin2.default)({
            mentionTrigger: "@"
        });

        let storyPlugin = (0, _draftJsMentionPlugin2.default)({
            mentionTrigger: "$"
        });

        _this.plugins = [hashtagPlugin, mentionPlugin, storyPlugin];
        _this.HashtagSuggestions = hashtagPlugin.MentionSuggestions;
        _this.MentionSuggestions = mentionPlugin.MentionSuggestions;
        _this.StorySuggestions = storyPlugin.MentionSuggestions;

        _this.state.mentionSuggestions = props.mentions;
        _this.state.hashtagSuggestions = props.hashtags;
        _this.state.storySuggestions = props.stories;

        _this.onChange = function (editorState) {
            props.onChange(editorState);
            _this.setState({editorState: editorState});
        };
        return _this;
    }

    _createClass(SearchFieldEditor, [{
        key: 'render',
        value: function render() {
            let _this2 = this;

            let HashtagSuggestions = this.HashtagSuggestions;
            let MentionSuggestions = this.MentionSuggestions;
            let StorySuggestions = this.StorySuggestions;

            return _react2.default.createElement(
                'div',
                {
                    className: 'search-field',
                    onClick: this.focus
                },
                _react2.default.createElement(_draftJsPluginsEditor2.default, {
                    editorState: this.state.editorState,
                    onChange: this.onChange,
                    spellCheck: true,
                    plugins: this.plugins,
                    ref: function ref(element) {
                        _this2.editor = element;
                    }
                }),
                _react2.default.createElement(MentionSuggestions, {
                    onSearchChange: this.onSearchChange,
                    suggestions: this.state.mentionSuggestions,
                    onAddMention: this.onAddMention
                }),
                _react2.default.createElement(HashtagSuggestions, {
                    onSearchChange: this.onSearchChange2,
                    suggestions: this.state.hashtagSuggestions,
                    onAddMention: this.onAddMention
                }),
                _react2.default.createElement(StorySuggestions, {
                    onSearchChange: this.onSearchChangeStories,
                    suggestions: this.state.storySuggestions,
                    onAddMention: this.onAddStory
                })
            );
        }
    }]);

    return SearchFieldEditor;
}(_react.Component);

exports.default = SearchFieldEditor;
