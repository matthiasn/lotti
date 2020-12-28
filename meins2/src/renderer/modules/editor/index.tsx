import React, { KeyboardEvent, useCallback, useMemo, useState } from 'react'
import Editor from '@draft-js-plugins/editor'
import createMentionPlugin, {
  defaultSuggestionsFilter,
  MentionData,
} from '@draft-js-plugins/mention'
import createLinkifyPlugin from '@draft-js-plugins/linkify'
import {
  convertFromRaw,
  EditorState,
  getDefaultKeyBinding,
  KeyBindingUtil,
  DraftHandleValue,
  RichUtils,
  DraftEditorCommand,
} from 'draft-js'
import { mdToDraftjs } from 'draftjs-md-converter'
import 'draft-js/dist/Draft.css'
import { Entry } from '../../../generated/graphql'
import '@draft-js-plugins/mention/lib/plugin.css'
import { logMarkdown } from './markdown'
import { EditMenu } from './editor-menu'

const { hasCommandModifier } = KeyBindingUtil

const mentions = [
  {
    name: '#meh',
  },
  {
    name: '#awesome',
  },
  {
    name: '#nice',
  },
] as MentionData[]

export function EditorView({ item }: { item: Entry }) {
  const [editorState, setEditorState] = useState(() =>
    EditorState.createWithContent(
      convertFromRaw(mdToDraftjs(item.md || item.text || '')),
    ),
  )
  const [suggestions, setSuggestions] = useState(mentions)
  const [open, setOpen] = useState(true)

  const { HashtagSuggestions, plugins } = useMemo(() => {
    const linkifyPlugin = createLinkifyPlugin()
    const hashtagPlugin = createMentionPlugin({ mentionTrigger: '#' })
    const { MentionSuggestions } = hashtagPlugin
    const plugins = [hashtagPlugin, linkifyPlugin]
    return { plugins, HashtagSuggestions: MentionSuggestions }
  }, [])

  function keyBindingFn(e: KeyboardEvent): DraftEditorCommand {
    if (e.keyCode === 83 /* `S` key */ && hasCommandModifier(e)) {
      //return 'editor-save'
    }
    return getDefaultKeyBinding(e)
  }

  function handleKeyCommand(command: string): DraftHandleValue {
    const newState = RichUtils.handleKeyCommand(editorState, command)

    if (newState) {
      setEditorState(newState)
      return 'handled'
    }

    if (command === 'editor-save') {
      logMarkdown(editorState)
      return 'handled'
    }
    return 'not-handled'
  }

  function onSearchChange({ value }: { value: string }) {
    console.log(value)
    setSuggestions(defaultSuggestionsFilter(value, mentions))
  }

  const onOpenChange = useCallback((_open: boolean) => {
    setOpen(_open)
  }, [])

  return (
    <div className="entry-text">
      <EditMenu editorState={editorState} setEditorState={setEditorState} />
      <Editor
        editorState={editorState}
        onChange={setEditorState}
        placeholder=""
        keyBindingFn={keyBindingFn}
        handleKeyCommand={handleKeyCommand}
        plugins={plugins}
      />
      <HashtagSuggestions
        onSearchChange={onSearchChange}
        suggestions={suggestions}
        onOpenChange={onOpenChange}
        open={open}
      />
    </div>
  )
}
