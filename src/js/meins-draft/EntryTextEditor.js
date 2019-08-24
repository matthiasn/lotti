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

// Get the first 15 suggestions that match
function size(list) {
    return list.constructor.name === 'List' ? list.size : list.length;
}

function get(obj, attr) {
    return obj.get ? obj.get(attr) : obj[attr];
}

function suggestionsFilter(searchValue, suggestions) {
    let t0 = performance.now();
    let value = searchValue.toLowerCase();

    let filteredSuggestions = suggestions.filter(function (suggestion) {
        return !value || get(suggestion, 'name').toLowerCase().indexOf(value) > -1;
    });
    let length = size(filteredSuggestions) < 15 ? size(filteredSuggestions) : 15;
    let t1 = performance.now();
    //console.log("suggestionsFilter took " + (t1 - t0) + "ms.");
    return filteredSuggestions.slice(0, length);
}

let _react = require('react');
let _react2 = _interopRequireDefault(_react);

let _draftJs = require('draft-js');
let _draftjsMdConverter = require('@matthiasn/draftjs-md-converter');

let _draftJsPluginsEditor = require('draft-js-plugins-editor');
let _draftJsPluginsEditor2 = _interopRequireDefault(_draftJsPluginsEditor);

let _draftJsMentionPlugin = require('draft-js-mention-plugin');
let _draftJsMentionPlugin2 = _interopRequireDefault(_draftJsMentionPlugin);

let _draftJsLinkifyPlugin = require('draft-js-linkify-plugin');
let _draftJsLinkifyPlugin2 = _interopRequireDefault(_draftJsLinkifyPlugin);

let _styleControls = require('./StyleControls');
let _styleControls2 = _interopRequireDefault(_styleControls);

let _lodash = require('lodash.throttle');
let _lodash2 = _interopRequireDefault(_lodash);

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

let hasCommandModifier = _draftJs.KeyBindingUtil.hasCommandModifier;


function myKeyBindingFn(e) {
    if (e.keyCode === 82 /* `E` key */ && hasCommandModifier(e)) {
        return 'editor-start';
    }if (e.keyCode === 83 /* `S` key */ && hasCommandModifier(e)) {
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

let myMdDict = {
    BOLD: '**',
    STRIKETHROUGH: '~~',
    CODE: '`',
    UNDERLINE: "__"
};

function extractAndSave (editorState, saveFn) {
    let t0 = performance.now();
    let content = editorState.getCurrentContent();
    let plain = content.getPlainText();
    let rawContent = _draftJs.convertToRaw(content);
    let t1 = performance.now();
    let md = _draftjsMdConverter.draftjsToMd(rawContent, myMdDict);
    let t2 = performance.now();
    console.log("SAVE convertToRaw took   " + (t1 - t0) + "ms.");
    console.log("SAVE draftjsToMd took    " + (t2 - t1) + "ms.");

    saveFn(md, plain);
}

let extraStyles = {
    inlineStyles: {
        Strong: {
            type: 'BOLD',
            symbol: '**'
        },
        Code: {
            type: 'CODE',
            symbol: '`'
        },
        Strikethrough: {
            type: 'STRIKETHROUGH',
            symbol: '~~'
        },
        Underline: {
            type: 'UNDERLINE',
            symbol: '__'
        }
    }
};

let EntryTextEditor = function (_Component) {
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

        let _this = _possibleConstructorReturn(this, (EntryTextEditor.__proto__ || Object.getPrototypeOf(EntryTextEditor)).call(this, props));

        _this.state = {};

        _this.handleKeyCommand = function (command) {
            let editorState = _this.state.editorState;

            if (command === 'editor-save') {
                extractAndSave (editorState, _this.props.saveFn);
                return 'handled';
            }

            if (command === 'editor-start') {
                _this.props.startFn();
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

            let newState = _draftJs.RichUtils.handleKeyCommand(editorState, command);
            if (newState) {
                _this.onChange(newState);
                return true;
            }
            return false;
        };

        _this.onSearchChange = function (_ref) {
            let value = _ref.value;
            let mentions = _this.state.mentions;

            _this.setState({
                mentionSuggestions: suggestionsFilter(value, mentions)
            });
        };

        _this.onSearchChange2 = function (_ref2) {
            let value = _ref2.value;
            let hashtags = _this.state.hashtags;

            _this.setState({
                hashtagSuggestions: suggestionsFilter(value, hashtags)
            });
        };

        _this.focus = function () {
            _this.editor.focus();
        };

        _this.onAddMention = function () {
        };


        _this.componentWillReceiveProps = function (nextProps) {
            // let t0 = performance.now();
            // let sinceUpdate = Date.now() - _this.state.lastUpdated;
            //
            // _this.state.mentions = nextProps.mentions;
            // _this.state.hashtags = nextProps.hashtags;
            //
            // if (sinceUpdate > 250) {
            //     let rawFromMd = _draftjsMdConverter.mdToDraftjs(nextProps.md);
            //     let content = _draftJs.convertFromRaw(rawFromMd);
            //     let newState = _draftJs.EditorState.createWithContent(content);
            //     _this.setState({editorState: newState});
            // }
            // let t1 = performance.now();
            // console.log("componentWillReceiveProps took " + (t1 - t0) + "ms.");
        };

        _this.handleKeyCommand = _this.handleKeyCommand.bind(_this);

        let rawFromMd = _draftjsMdConverter.mdToDraftjs(props.md, extraStyles);
        let stateFromMd = _draftJs.convertFromRaw(rawFromMd);
        let stateFromMd2 = _draftJs.EditorState.createWithContent(stateFromMd);

        _this.state.editorState = props.editorState ? props.editorState : stateFromMd2;

        _this.toggleInlineStyle = function (style) {
            return _this._toggleInlineStyle(style);
        };
        _this.toggleBlockType = function (type) {
            return _this._toggleBlockType(type);
        };

        let hashtagPlugin = _draftJsMentionPlugin2.default({mentionTrigger: "#"});
        let mentionPlugin = _draftJsMentionPlugin2.default({mentionTrigger: "@"});
        let linkifyPlugin = _draftJsLinkifyPlugin2.default ({
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

        //_this.plugins = [linkifyPlugin];
        _this.plugins = [hashtagPlugin, mentionPlugin, linkifyPlugin];
        _this.HashtagSuggestions = hashtagPlugin.MentionSuggestions;
        _this.MentionSuggestions = mentionPlugin.MentionSuggestions;

        _this.state.mentions = props.mentions;
        _this.state.hashtags = props.hashtags;

        _this.state.mentionSuggestions = props.mentions;
        _this.state.hashtagSuggestions = props.hashtags;

        _this.changeCallback = function (newState) {
            let t0 = performance.now();
            let content = newState.getCurrentContent();
            let plain = content.getPlainText();
            let rawContent = _draftJs.convertToRaw(content);
            let t1 = performance.now();
            let md = _draftjsMdConverter.draftjsToMd(rawContent, myMdDict);
            let t2 = performance.now();

            localStorage.setItem(props.ts, md);
            console.log(localStorage.getItem(props.ts));

            //props.onChange(md, plain);

            console.log("convertToRaw " + (t1 - t0) + " draftjsToMd "+ (t2 - t1));
        };

        _this.onChange = function (newState) {
            let now = Date.now();
            _this.setState({
                editorState: newState,
                lastUpdated: now
            });
            //_this.changeCallback(newState);
            props.onChange(newState);
        };
        return _this;
    }

    _createClass(EntryTextEditor, [{
        key: 'render',
        value: function render() {
            let _this2 = this;
            let HashtagSuggestions = this.HashtagSuggestions;
            let MentionSuggestions = this.MentionSuggestions;
            let editorState = this.state.editorState;

            let save = () => {
                extractAndSave(editorState, this.props.saveFn)
            };
            return _react2.default.createElement(
                'div',
                {
                    className: 'entry-text',
                    onClick: this.focus
                },
                _react2.default.createElement(_styleControls2.default, {
                    editorState: editorState,
                    state: this,
                    //show: this.props.changed,
                    show: true,
                    save: save,
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
                })
            );
        }
    }]);

    return EntryTextEditor;
}(_react.Component);

exports.default = EntryTextEditor;
