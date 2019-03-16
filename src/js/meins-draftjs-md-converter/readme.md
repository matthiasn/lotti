[![npm version](https://badge.fury.io/js/draftjs-md-converter.svg)](https://badge.fury.io/js/draftjs-md-converter)

# Draft.js to Markdown to Draft.js converter

Converts rich text content between Draft.js blocks and Markdown.

## Reasoning and background

This library exists because I needed a highly customisable rich text editor which posts to an external API in Markdown. [Draft.js](https://facebook.github.io/draft-js/) to the rescue! It provides the editor state but, alas, doesn't ship with any sort of conversion to or from markdown. So, I've written my own.

## Installation

```
npm install draftjs-md-converter
```

## Support

The following inline styles are supported:

* bold
* italic
* H1 - H6

The following block styles are supported:

* ordered list
* unordered list
* block quote

The following media types are supported:

* images
* videos (with draft-js-video-plugin, parsing can be done using remark-shortcodes)

## Usage

### Converting from Markdown to Draft.js
### `mdToDraftjs(markdown: String): RawDraftContentState`

Use [convertToRaw](https://facebook.github.io/draft-js/docs/api-reference-data-conversion.html) from the `draft-js library` to convert the resulting RawDraftContentState into a draft-js ContentState.

### Converting from Draft.js to Markdown
### `draftjsToMd(rawData: RawDraftContentState): String`

Use [convertFromRaw](https://facebook.github.io/draft-js/docs/api-reference-data-conversion.html) from the `draft-js library` to get the raw RawDraftContentState to then pass into the converter.

### Custom dictionaries

The default Markdown dictionary is

```js
{
  BOLD: '__',
  ITALIC: '*'
};
```

The inline styles can be extended or overridden by passing a custom dictionary object as a second optional argument to `draftjsToMd`, e.g.

```js
const myMdDict = {
  BOLD: '**',
  STRIKETHROUGH: '~~'
};
const markdown = draftjsToMd(blocks, myMdDict);
```

__NOTE: at this point you cannot override block styles!__

## Example

```js
[---]

import { mdToDraftjs, draftjsToMd } from 'draftjs-md-converter';
import { EditorState, ContentState, convertToRaw, convertFromRaw } from 'draft-js';

[---]

constructor(props) {
  super(props);

  // some default value in markdown
  const defaultValue = this.props.defaultValue;
  const rawData = mdToDraftjs(defaultValue);
  const contentState = convertFromRaw(rawData);
  const newEditorState = EditorState.createWithContent(contentState);

  this.state = {
    editorState: newEditorState,
  };
  this.onChange = (editorState) => {
    this.props.onChange(this.getMarkdown());
    this.setState({ editorState });
  };
}

[---]

getMarkdown() {
  const content = this.state.editorState.getCurrentContent();
  return draftjsToMd(convertToRaw(content));
}

[---]
```

## Run tests

```
npm test
```

## Run tests with a watcher

```
npm run test-dev
```

## Lint

```
npm run lint
```

## Adapted for meins

Removed a duplicate function definition in `dist/index.js` as that caused the Closure compiler to fail.
