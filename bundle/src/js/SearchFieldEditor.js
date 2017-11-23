import React, {Component} from 'react';
import Editor, {createEditorStateWithText} from 'draft-js-plugins-editor'; // eslint-disable-line import/no-unresolved
import createMentionPlugin, {defaultSuggestionsFilter} from 'draft-js-mention-plugin'; // eslint-disable-line import/no-unresolved
import editorStyles from './editorStyles.css';

export default class SearchFieldEditor extends Component {

    state = {};

    onSearchChange = ({value}) => {
        let mentions = this.props.mentions;
        this.setState({
            mentionSuggestions: defaultSuggestionsFilter(value, mentions),
        });
    };

    onSearchChange2 = ({value}) => {
        let hashtags = this.props.hashtags;
        this.setState({
            hashtagSuggestions: defaultSuggestionsFilter(value, hashtags),
        });
    };

    onSearchChangeStories = ({value}) => {
        let stories = this.props.stories;
        this.setState({
            storySuggestions: defaultSuggestionsFilter(value, stories),
        });
    };

    focus = () => {
        this.editor.focus();
    };

    onAddMention = () => {
        // get the mention object selected
    };

    onAddStory = (story) => {
    };

    constructor(props) {
        super(props);
        this.state.editorState = props.editorState;

        const hashtagPlugin = createMentionPlugin({
            mentionTrigger: "#",
        });

        const mentionPlugin = createMentionPlugin({
            mentionTrigger: "@",
        });

        const storyPlugin = createMentionPlugin({
            mentionTrigger: "$",
        });

        this.plugins = [hashtagPlugin, mentionPlugin, storyPlugin];
        this.HashtagSuggestions = hashtagPlugin.MentionSuggestions;
        this.MentionSuggestions = mentionPlugin.MentionSuggestions;
        this.StorySuggestions = storyPlugin.MentionSuggestions;

        this.state.mentionSuggestions = props.mentions;
        this.state.hashtagSuggestions = props.hashtags;
        this.state.storySuggestions = props.stories;

        this.onChange = (editorState) => {
            props.onChange(editorState);
            this.setState({editorState});
        };
    }

    render() {
        const HashtagSuggestions = this.HashtagSuggestions;
        const MentionSuggestions = this.MentionSuggestions;
        const StorySuggestions = this.StorySuggestions;
        return (
            <div className="search-field"
                 onClick={this.focus}>
                <Editor
                    editorState={this.state.editorState}
                    onChange={this.onChange}
                    spellCheck={true}
                    plugins={this.plugins}
                    ref={(element) => {
                        this.editor = element;
                    }}
                />
                <MentionSuggestions
                    onSearchChange={this.onSearchChange}
                    suggestions={this.state.mentionSuggestions}
                    onAddMention={this.onAddMention}
                />
                <HashtagSuggestions
                    onSearchChange={this.onSearchChange2}
                    suggestions={this.state.hashtagSuggestions}
                    onAddMention={this.onAddMention}
                />
                <StorySuggestions
                    onSearchChange={this.onSearchChangeStories}
                    suggestions={this.state.storySuggestions}
                    onAddMention={this.onAddStory}
                />
            </div>
        );
    }
}
