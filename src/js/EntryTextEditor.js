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

var _react2 = _interopRequireDefault(_react);

var _draftjsMdConverter = require('draftjs-md-converter');

var _draftJsExportMarkdown = require('draft-js-export-markdown');

var _draftJsExportHtml = require('draft-js-export-html');

var _draftJs = require('draft-js');

var _draftJsPluginsEditor = require('draft-js-plugins-editor');

var _draftJsPluginsEditor2 = _interopRequireDefault(_draftJsPluginsEditor);

var _draftJsMentionPlugin = require('draft-js-mention-plugin');

var _draftJsMentionPlugin2 = _interopRequireDefault(_draftJsMentionPlugin);

var _draftJsLinkifyPlugin = require('draft-js-linkify-plugin');

var _draftJsLinkifyPlugin2 = _interopRequireDefault(_draftJsLinkifyPlugin);

var _styleControls = require('./StyleControls');

var _styleControls2 = _interopRequireDefault(_styleControls);

var _lodash = require('lodash.throttle');

var _lodash2 = _interopRequireDefault(_lodash);

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
// eslint-disable-line import/no-unresolved
// eslint-disable-line import/no-unresolved


var hasCommandModifier = _draftJs.KeyBindingUtil.hasCommandModifier;


function myKeyBindingFn(e) {
    if (e.keyCode === 83 /* `S` key */ && hasCommandModifier(e)) {
        return 'editor-save';
    }
    if (e.keyCode === 187 && hasCommandModifier(e)) {
        return 'cmd-plus';
    }
    if (e.keyCode === 189 && hasCommandModifier(e)) {
        return 'cmd-minus';
    }
    return (0, _draftJs.getDefaultKeyBinding)(e);
}

var myMdDict = {
    BOLD: '**',
    STRIKETHROUGH: '~~',
    CODE: '`',
    UNDERLINE: "__"
};

var EntryTextEditor = function (_Component) {
    _inherits(EntryTextEditor, _Component);

    _createClass(EntryTextEditor, [{
        key: '_toggleInlineStyle',
        value: function _toggleInlineStyle(inlineStyle) {
            this.onChange(_draftJs.RichUtils.toggleInlineStyle(this.state.editorState, inlineStyle));
        }
    }, {
        key: '_toggleBlockType',
        value: function _toggleBlockType(blockType) {
            this.onChange(_draftJs.RichUtils.toggleBlockType(this.state.editorState, blockType));
        }
    }]);

    function EntryTextEditor(props) {
        _classCallCheck(this, EntryTextEditor);

        var _this = _possibleConstructorReturn(this, (EntryTextEditor.__proto__ || Object.getPrototypeOf(EntryTextEditor)).call(this, props));

        _this.state = {};

        _this.handleKeyCommand = function (command) {
            var editorState = _this.state.editorState;


            if (command === 'editor-save') {
                _this.props.saveFn();
                return 'handled';
            }

            if (command === 'cmd-plus') {
                _this.props.smallImg(false);
                return 'handled';
            }
            if (command === 'cmd-minus') {
                _this.props.smallImg(true);
                return 'handled';
            }

            var newState = _draftJs.RichUtils.handleKeyCommand(editorState, command);
            if (newState) {
                _this.onChange(newState);
                return true;
            }
            return false;
        };

        _this.onSearchChange = function (_ref) {
            var value = _ref.value;

            var mentions = _this.state.mentions;
            _this.setState({
                mentionSuggestions: (0, _draftJsMentionPlugin.defaultSuggestionsFilter)(value, mentions)
            });
        };

        _this.onSearchChange2 = function (_ref2) {
            var value = _ref2.value;

            var hashtags = _this.state.hashtags;
            _this.setState({
                hashtagSuggestions: (0, _draftJsMentionPlugin.defaultSuggestionsFilter)(value, hashtags)
            });
        };

        _this.onSearchChangeStories = function (_ref3) {
            var value = _ref3.value;

            var stories = _this.state.stories;
            _this.setState({
                storySuggestions: (0, _draftJsMentionPlugin.defaultSuggestionsFilter)(value, stories)
            });
        };

        _this.focus = function () {
            _this.editor.focus();
        };

        _this.onAddMention = function () {
        };

        _this.onAddStory = function (story) {
        };

        _this.componentWillReceiveProps = function (nextProps) {
            var nextEditorState = nextProps.editorState;
            var currentEditorState = _this.state.editorState;
            var sinceUpdate = Date.now() - _this.state.lastUpdated;

            _this.state.mentions = nextProps.mentions;
            _this.state.hashtags = nextProps.hashtags;
            _this.state.stories = nextProps.stories;

            if (nextEditorState && currentEditorState && sinceUpdate > 1000) {
                var nextPropsContent = nextEditorState.getCurrentContent();
                var currentContent = currentEditorState.getCurrentContent();
                var nextPropsPlain = nextPropsContent.getPlainText();
                var statePlain = currentContent.getPlainText();
                var changedOutside = nextPropsPlain !== statePlain;
                if (changedOutside) {
                    _this.setState({editorState: nextProps.editorState});
                }
            }
        };

        _this.handleKeyCommand = _this.handleKeyCommand.bind(_this);
        var stateFromMd = (0, _draftJs.convertFromRaw)((0, _draftjsMdConverter.mdToDraftjs)(props.md));
        var stateFromMd2 = _draftJs.EditorState.createWithContent(stateFromMd);
        _this.state.editorState = props.editorState ? props.editorState : stateFromMd2;
        _this.toggleInlineStyle = function (style) {
            return _this._toggleInlineStyle(style);
        };
        _this.toggleBlockType = function (type) {
            return _this._toggleBlockType(type);
        };

        var hashtagPlugin = (0, _draftJsMentionPlugin2.default)({mentionTrigger: "#"});
        var mentionPlugin = (0, _draftJsMentionPlugin2.default)({mentionTrigger: "@"});
        var storyPlugin = (0, _draftJsMentionPlugin2.default)({mentionTrigger: "$"});
        var linkifyPlugin = (0, _draftJsLinkifyPlugin2.default)({
            target: "_blank",
            component: function component(props) {
                return (
                    // eslint-disable-next-line no-alert, jsx-a11y/anchor-has-content
                    _react2.default.createElement('a', _extends({}, props, {
                        onClick: function onClick() {
                            window.open(props.href, '_blank');
                        }
                    }))
                );
            }
        });

        _this.plugins = [hashtagPlugin, mentionPlugin, storyPlugin, linkifyPlugin];
        _this.HashtagSuggestions = hashtagPlugin.MentionSuggestions;
        _this.MentionSuggestions = mentionPlugin.MentionSuggestions;
        _this.StorySuggestions = storyPlugin.MentionSuggestions;

        _this.state.mentions = props.mentions;
        _this.state.hashtags = props.hashtags;
        _this.state.stories = props.stories;

        _this.state.mentionSuggestions = props.mentions;
        _this.state.hashtagSuggestions = props.hashtags;
        _this.state.storySuggestions = props.stories;

        _this.saveExternal = function (newState) {
            var content = newState.getCurrentContent();
            var plain = content.getPlainText();
            var rawContent = (0, _draftJs.convertToRaw)(content);
            var rawContent2 = JSON.parse(JSON.stringify(rawContent));
            var md = (0, _draftjsMdConverter.draftjsToMd)(rawContent, myMdDict);
            //const md2 = stateToMarkdown(content);
            //const html = stateToHTML(content);
            //console.log(md);
            //console.log(html);
            //console.log(md2);
            props.onChange(md, plain, rawContent2);
        };

        _this.throttledSave = (0, _lodash2.default)(_this.saveExternal, 500);

        _this.onChange = function (newState) {
            var now = Date.now();
            _this.setState({
                editorState: newState,
                lastUpdated: now
            });
            _this.throttledSave(newState);
        };
        return _this;
    }

    _createClass(EntryTextEditor, [{
        key: 'render',
        value: function render() {
            var _this2 = this;

            var HashtagSuggestions = this.HashtagSuggestions;
            var MentionSuggestions = this.MentionSuggestions;
            var StorySuggestions = this.StorySuggestions;
            var editorState = this.state.editorState;


            return _react2.default.createElement(
                'div',
                {
                    className: 'entry-text',
                    onClick: this.focus
                },
                _react2.default.createElement(_styleControls2.default, {
                    editorState: editorState,
                    state: this,
                    show: this.props.changed,
                    onToggleInline: this.toggleInlineStyle,
                    onToggleBlockType: this.toggleBlockType
                }),
                _react2.default.createElement(_draftJsPluginsEditor2.default, {
                    editorState: editorState,
                    onChange: this.onChange,
                    plugins: this.plugins,
                    handleKeyCommand: this.handleKeyCommand,
                    keyBindingFn: myKeyBindingFn,
                    spellCheck: true,
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

    return EntryTextEditor;
}(_react.Component);

exports.default = EntryTextEditor;
