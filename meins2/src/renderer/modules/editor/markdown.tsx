import React from 'react'
import { convertToRaw, EditorState } from 'draft-js'
import { draftjsToMd } from 'draftjs-md-converter'
import 'draft-js/dist/Draft.css'
import '@draft-js-plugins/mention/lib/plugin.css'

export function logMarkdown(editorState: EditorState) {
  const content = editorState.getCurrentContent()
  const md = draftjsToMd(convertToRaw(content))
  const text = content.getPlainText()
  console.log(md)
  console.log(text)
}
