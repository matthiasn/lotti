'use strict';

const defaultMarkdownDict = {
  BOLD: '__',
  ITALIC: '*'
};

const blockStyleDict = {
  'unordered-list-item': '- ',
  'header-one': '# ',
  'header-two': '## ',
  'header-three': '### ',
  'header-four': '#### ',
  'header-five': '##### ',
  'header-six': '###### ',
  blockquote: '> '
};

const wrappingBlockStyleDict = {
  'code-block': '```'
};

const getBlockStyle = (currentStyle, appliedBlockStyles) => {
  if (currentStyle === 'ordered-list-item') {
    const counter = appliedBlockStyles.reduce((prev, style) => {
      if (style === 'ordered-list-item') {
        return prev + 1;
      }
      return prev;
    }, 1);
    return `${counter}. `;
  }
  return blockStyleDict[currentStyle] || '';
};

const applyWrappingBlockStyle = (currentStyle, content) => {
  if (currentStyle in wrappingBlockStyleDict) {
    const wrappingSymbol = wrappingBlockStyleDict[currentStyle];
    return `${wrappingSymbol}\n${content}\n${wrappingSymbol}`;
  }

  return content;
};

const applyAtomicStyle = (block, entityMap, content) => {
  if (block.type !== 'atomic') return content;
  // strip the test that was added in the media block
  const strippedContent = content.substring(0, content.length - block.text.length);
  const key = block.entityRanges[0].key;
  const type = entityMap[key].type;
  const data = entityMap[key].data;
  if (type === 'draft-js-video-plugin-video') {
    return `${strippedContent}[[ embed url=${data.url || data.src} ]]`;
  }
  return `${strippedContent}![${data.fileName || ''}](${data.url || data.src})`;
};

const getEntityStart = entity => {
  switch (entity.type) {
    case 'LINK':
      return '[';
    default:
      return '';
  }
};

const getEntityEnd = entity => {
  switch (entity.type) {
    case 'LINK':
      return `](${entity.data.url})`;
    default:
      return '';
  }
};

function fixWhitespacesInsideStyle(text, style) {
  const { symbol } = style;

  // Text before style-opening marker (including the marker)
  const pre = text.slice(0, style.range.start);
  // Text between opening and closing markers
  const body = text.slice(style.range.start, style.range.end);
  // Trimmed text between markers
  const bodyTrimmed = body.trim();
  // Text after closing marker
  const post = text.slice(style.range.end);

  const bodyTrimmedStart = style.range.start + body.indexOf(bodyTrimmed);

  // Text between opening marker and trimmed content (leading spaces)
  const prefix = text.slice(style.range.start, bodyTrimmedStart);
  // Text between the end of trimmed content and closing marker (trailing spaces)
  const postfix = text.slice(bodyTrimmedStart + bodyTrimmed.length, style.range.end);

  // Temporary text that contains trimmed content wrapped into original pre- and post-texts
  const newText = `${pre}${bodyTrimmed}${post}`;
  // Insert leading and trailing spaces between pre-/post- contents and their respective markers
  return newText.replace(
    `${symbol}${bodyTrimmed}${symbol}`,
    `${prefix}${symbol}${bodyTrimmed}${symbol}${postfix}`
  );
}

function getInlineStyleRangesByLength(inlineStyleRanges) {
  return [...inlineStyleRanges].sort((a, b) => b.length - a.length);
}

function draftjsToMd(raw, extraMarkdownDict) {
  const markdownDict = { ...defaultMarkdownDict, ...extraMarkdownDict };
  let returnString = '';
  const appliedBlockStyles = [];

  // totalOffset is a difference of index position between raw string and enhanced ones
  let totalOffset = 0;

  raw.blocks.forEach((block, blockIndex) => {
    if (blockIndex !== 0) {
      returnString += '\n';
      totalOffset = 0;
    }

    // add block style
    returnString += getBlockStyle(block.type, appliedBlockStyles);
    appliedBlockStyles.push(block.type);

    const appliedStyles = [];
    returnString += block.text.split('').reduce((text, currentChar, index) => {
      let newText = text;

      const sortedInlineStyleRanges = getInlineStyleRangesByLength(block.inlineStyleRanges);

      // find all styled at this character
      const stylesStartAtChar = sortedInlineStyleRanges
        .filter(range => range.offset === index)
        .filter(range => markdownDict[range.style]); // disregard styles not defined in the md dict

      // add the symbol to the md string and push the style in the applied styles stack
      stylesStartAtChar.forEach(currentStyle => {
        const symbolLength = markdownDict[currentStyle.style].length;
        newText += markdownDict[currentStyle.style];
        totalOffset += symbolLength;
        appliedStyles.push({
          symbol: markdownDict[currentStyle.style],
          range: {
            start: currentStyle.offset + totalOffset,
            end: currentStyle.offset + currentStyle.length + totalOffset
          },
          end: currentStyle.offset + (currentStyle.length - 1)
        });
      });

      // check for entityRanges starting and add if existing
      const entitiesStartAtChar = block.entityRanges.filter(range => range.offset === index);
      entitiesStartAtChar.forEach(entity => {
        newText += getEntityStart(raw.entityMap[entity.key]);
      });

      // add the current character to the md string
      newText += currentChar;

      // check for entityRanges ending and add if existing
      const entitiesEndAtChar = block.entityRanges.filter(
        range => range.offset + range.length - 1 === index
      );
      entitiesEndAtChar.forEach(entity => {
        newText += getEntityEnd(raw.entityMap[entity.key]);
      });

      // apply the 'ending' tags for any styles that end in the current position in order (stack)
      while (appliedStyles.length !== 0 && appliedStyles[appliedStyles.length - 1].end === index) {
        const endingStyle = appliedStyles.pop();
        newText += endingStyle.symbol;

        newText = fixWhitespacesInsideStyle(newText, endingStyle);
        totalOffset += endingStyle.symbol.length;
      }

      return newText;
    }, '');

    returnString = applyWrappingBlockStyle(block.type, returnString);
    returnString = applyAtomicStyle(block, raw.entityMap, returnString);
  });
  return returnString;
}

module.exports.draftjsToMd = draftjsToMd;
