'use strict';

const parse = require('@textlint/markdown-to-ast').parse;

const defaultInlineStyles = {
  Strong: {
    type: 'BOLD',
    symbol: '__'
  },
  Emphasis: {
    type: 'ITALIC',
    symbol: '*'
  }
};

const defaultBlockStyles = {
  List: 'unordered-list-item',
  Header1: 'header-one',
  Header2: 'header-two',
  Header3: 'header-three',
  Header4: 'header-four',
  Header5: 'header-five',
  Header6: 'header-six',
  CodeBlock: 'code-block',
  BlockQuote: 'blockquote'
};

const getBlockStyleForMd = (node, blockStyles) => {
  const style = node.type;
  const ordered = node.ordered;
  const depth = node.depth;
  if (style === 'List' && ordered) {
    return 'ordered-list-item';
  } else if (style === 'Header') {
    return blockStyles[`${style}${depth}`];
  } else if (
    node.type === 'Paragraph' &&
    node.children &&
    node.children[0] &&
    node.children[0].type === 'Image'
  ) {
    return 'atomic';
  } else if (node.type === 'Paragraph' && node.raw && node.raw.match(/^\[\[\s\S+\s.*\S+\s\]\]/)) {
    return 'atomic';
  }
  return blockStyles[style];
};

const joinCodeBlocks = splitMd => {
  const opening = splitMd.indexOf('```');
  const closing = splitMd.indexOf('```', opening + 1);

  if (opening >= 0 && closing >= 0) {
    const codeBlock = splitMd.slice(opening, closing + 1);
    const codeBlockJoined = codeBlock.join('\n');
    const updatedSplitMarkdown = [
      ...splitMd.slice(0, opening),
      codeBlockJoined,
      ...splitMd.slice(closing + 1)
    ];

    return joinCodeBlocks(updatedSplitMarkdown);
  }

  return splitMd;
};

const splitMdBlocks = md => {
  const splitMd = md.split('\n');

  // Process the split markdown include the
  // one syntax where there's an block level opening
  // and closing symbol with content in the middle.
  const splitMdWithCodeBlocks = joinCodeBlocks(splitMd);
  return splitMdWithCodeBlocks;
};

const parseMdLine = (line, existingEntities, extraStyles = {}) => {
  const inlineStyles = { ...defaultInlineStyles, ...extraStyles.inlineStyles };
  const blockStyles = { ...defaultBlockStyles, ...extraStyles.blockStyles };

  const astString = parse(line);
  let text = '';
  const inlineStyleRanges = [];
  const entityRanges = [];
  const entityMap = existingEntities;

  const addInlineStyleRange = (offset, length, style) => {
    inlineStyleRanges.push({ offset, length, style });
  };

  const getRawLength = children =>
    children.reduce((prev, current) => prev + (current.value ? current.value.length : 0), 0);

  const addLink = child => {
    const entityKey = Object.keys(entityMap).length;
    entityMap[entityKey] = {
      type: 'LINK',
      mutability: 'MUTABLE',
      data: {
        url: child.url
      }
    };
    entityRanges.push({
      key: entityKey,
      length: getRawLength(child.children),
      offset: text.length
    });
  };

  const addImage = child => {
    const entityKey = Object.keys(entityMap).length;
    entityMap[entityKey] = {
      type: 'IMAGE',
      mutability: 'IMMUTABLE',
      data: {
        url: child.url,
        src: child.url,
        fileName: child.alt || ''
      }
    };
    entityRanges.push({
      key: entityKey,
      length: 1,
      offset: text.length
    });
  };

  const addVideo = child => {
    const string = child.raw;

    // RegEx: [[ embed url=<anything> ]]
    const url = string.match(/^\[\[\s(?:embed)\s(?:url=(\S+))\s\]\]/)[1];

    const entityKey = Object.keys(entityMap).length;
    entityMap[entityKey] = {
      type: 'draft-js-video-plugin-video',
      mutability: 'IMMUTABLE',
      data: {
        src: url
      }
    };
    entityRanges.push({
      key: entityKey,
      length: 1,
      offset: text.length
    });
  };

  const parseChildren = (child, style) => {
    // RegEx: [[ embed url=<anything> ]]
    const videoShortcodeRegEx = /^\[\[\s(?:embed)\s(?:url=(\S+))\s\]\]/;
    switch (child.type) {
      case 'Link':
        addLink(child);
        break;
      case 'Image':
        addImage(child);
        break;
      case 'Paragraph':
        if (videoShortcodeRegEx.test(child.raw)) {
          addVideo(child);
        }
        break;
      default:
    }

    if (!videoShortcodeRegEx.test(child.raw) && child.children && style) {
      const rawLength = getRawLength(child.children);
      addInlineStyleRange(text.length, rawLength, style.type);
      const newStyle = inlineStyles[child.type];
      child.children.forEach(grandChild => {
        parseChildren(grandChild, newStyle);
      });
    } else if (!videoShortcodeRegEx.test(child.raw) && child.children) {
      const newStyle = inlineStyles[child.type];
      child.children.forEach(grandChild => {
        parseChildren(grandChild, newStyle);
      });
    } else {
      if (style) {
        addInlineStyleRange(text.length, child.value.length, style.type);
      }
      if (inlineStyles[child.type]) {
        addInlineStyleRange(text.length, child.value.length, inlineStyles[child.type].type);
      }
      text = `${text}${
        child.type === 'Image' || videoShortcodeRegEx.test(child.raw) ? ' ' : child.value
      }`;
    }
  };

  astString.children.forEach(child => {
    const style = inlineStyles[child.type];
    parseChildren(child, style);
  });

  // add block style if it exists
  let blockStyle = 'unstyled';
  if (astString.children[0]) {
    const style = getBlockStyleForMd(astString.children[0], blockStyles);
    if (style) {
      blockStyle = style;
    }
  }

  return {
    text,
    inlineStyleRanges,
    entityRanges,
    blockStyle,
    entityMap
  };
};

function mdToDraftjs(mdString, extraStyles) {
  const paragraphs = splitMdBlocks(mdString);
  const blocks = [];
  let entityMap = {};

  paragraphs.forEach(paragraph => {
    const result = parseMdLine(paragraph, entityMap, extraStyles);
    blocks.push({
      text: result.text,
      type: result.blockStyle,
      depth: 0,
      inlineStyleRanges: result.inlineStyleRanges,
      entityRanges: result.entityRanges
    });
    entityMap = result.entityMap;
  });

  // add a default value
  // not sure why that's needed but Draftjs convertToRaw fails without it
  if (Object.keys(entityMap).length === 0) {
    entityMap = {
      data: '',
      mutability: '',
      type: ''
    };
  }
  return {
    blocks,
    entityMap
  };
}

module.exports.mdToDraftjs = mdToDraftjs;
