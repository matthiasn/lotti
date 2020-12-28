import React, { Dispatch, SetStateAction } from 'react'
import { EditorState, RichUtils } from 'draft-js'
import 'draft-js/dist/Draft.css'
import '@draft-js-plugins/mention/lib/plugin.css'
import { logMarkdown } from './markdown'

export function EditMenu({
  editorState,
  setEditorState,
}: {
  editorState: EditorState
  setEditorState: Dispatch<SetStateAction<EditorState>>
}) {
  function toggleInlineStyle(inlineStyle: string) {
    setEditorState(RichUtils.toggleInlineStyle(editorState, inlineStyle))
  }

  function toggleBlockType(blockType: string) {
    setEditorState(RichUtils.toggleBlockType(editorState, blockType))
  }

  return (
    <div className="RichEditor-controls edit-menu">
      <i
        className="fa far fa-save fa-wide"
        onClick={() => logMarkdown(editorState)}
      />
      <i
        className="fa far fa-bold fa-wide"
        onClick={() => toggleInlineStyle('BOLD')}
      />
      <i
        className="fa far fa-italic fa-wide"
        onClick={() => toggleInlineStyle('ITALIC')}
      />
      <i
        className="fa far fa-underline fa-wide"
        onClick={() => toggleInlineStyle('UNDERLINE')}
      />
      <i
        className="fa far fa-code fa-wide"
        onClick={() => toggleInlineStyle('CODE')}
      />
      <i
        className="fa far fa-strikethrough fa-wide"
        onClick={() => toggleInlineStyle('STRIKETHROUGH')}
      />
      <i
        className="fa far fa-heading"
        onClick={() => toggleBlockType('header-one')}
      />
      <i
        className="fa far fa-heading header-2"
        onClick={() => toggleBlockType('header-two')}
      />
      <i
        className="fa far fa-heading header-3"
        onClick={() => toggleBlockType('header-three')}
      />
      <i
        className="fa far fa-list-ul fa-wide active-button"
        onClick={() => toggleBlockType('unordered-list-item')}
      />
      <i
        className="fa far fa-list-ol fa-wide"
        onClick={() => toggleBlockType('ordered-list-item')}
      />
    </div>
  )
}
