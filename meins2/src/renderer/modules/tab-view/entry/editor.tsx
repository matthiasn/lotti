import React, { useRef, useState } from 'react'
import { convertToRaw, convertFromRaw, Editor, EditorState } from 'draft-js'
import { mdToDraftjs, draftjsToMd } from 'draftjs-md-converter'
import 'draft-js/dist/Draft.css'
import { Entry } from '../../../../generated/graphql'

export function EditMenu({ editorState }: { editorState: EditorState }) {
  function logMarkdown() {
    const content = editorState.getCurrentContent()
    const md = draftjsToMd(convertToRaw(content))
    const text = content.getPlainText()
    console.log(md)
    console.log(text)
  }

  return (
    <div className="RichEditor-controls edit-menu">
      <i className="fa far fa-save fa-wide" onClick={logMarkdown} />
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
    EditorState.createWithContent(
      convertFromRaw(mdToDraftjs(item.md || item.text || '')),
    ),
  )

  const editor = useRef(null)

  function focusEditor() {
    editor.current.focus()
  }

  return (
    <div className="entry-text">
      <EditMenu editorState={editorState} />
      <Editor
        ref={editor}
        editorState={editorState}
        onChange={setEditorState}
        placeholder="Write something!"
      />
    </div>
  )
}
