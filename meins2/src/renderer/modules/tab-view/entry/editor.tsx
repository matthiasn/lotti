import React, { useRef, useState } from 'react'
import { ContentState, Editor, EditorState } from 'draft-js'
import 'draft-js/dist/Draft.css'
import { Entry } from '../../../../generated/graphql'

export function EditMenu() {
  return (
    <div className="RichEditor-controls edit-menu">
      <i className="fa far fa-save fa-wide" />
      <i className="fa far fa-bold fa-wide" />
      <i className="fa far fa-italic fa-wide" />
      <i className="fa far fa-underline fa-wide" />
      <i className="fa far fa-code fa-wide" />
      <i className="fa far fa-strikethrough fa-wide" />
      <i className="fa far fa-heading" />
      <i className="fa far fa-heading header-2" />
      <i className="fa far fa-heading header-3" />
      <i className="fa far fa-list-ul fa-wide active-button" />
      <i className="fa far fa-list-ol fa-wide" />
    </div>
  )
}

export function EditorView({ item }: { item: Entry }) {
  const [editorState, setEditorState] = useState(() =>
    EditorState.createWithContent(ContentState.createFromText(item.text || '')),
  )

  const editor = useRef(null)

  function focusEditor() {
    editor.current.focus()
  }

  return (
    <div className="entry-text">
      <EditMenu />
      <Editor
        ref={editor}
        editorState={editorState}
        onChange={setEditorState}
        placeholder="Write something!"
      />
    </div>
  )
}
