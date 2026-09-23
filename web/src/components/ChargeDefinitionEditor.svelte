<script lang="ts">
 import { onDestroy } from "svelte";
 import { Editor } from "@tiptap/core";
 import StarterKit from "@tiptap/starter-kit";
 import Underline from "@tiptap/extension-underline";
 import TextAlign from "@tiptap/extension-text-align";
 import Highlight from "@tiptap/extension-highlight";
 import TextStyle from "@tiptap/extension-text-style";
 import Color from "@tiptap/extension-color";
 import ReportEditorToolbar from "./report-editor/ReportEditorToolbar.svelte";

 let { content = "", onUpdate }: { content?: string; onUpdate: (value: string) => void } = $props();
 let editor = $state<Editor | null>(null);
 let element = $state<HTMLElement>();

 $effect(() => {
  if (!element || editor) return;
  editor = new Editor({ element, content, extensions: [StarterKit, Underline, TextAlign.configure({ types: ["heading", "paragraph"] }), Highlight.configure({ multicolor: true }), TextStyle, Color], onUpdate: ({ editor }) => onUpdate(editor.getHTML()), editorProps: { attributes: { class: "charge-editor-content" } } });
 });
 onDestroy(() => editor?.destroy());
</script>

<div class="charge-definition-editor">
 {#if editor}<ReportEditorToolbar {editor} />{/if}
 <div class="charge-editor-surface"><div bind:this={element}></div></div>
</div>

<style>
 .charge-definition-editor { border: 1px solid rgba(255,255,255,.1); border-radius: 3px; background: #0d1117; overflow: hidden; }
 .charge-editor-surface { min-height: 110px; max-height: 220px; overflow: auto; padding: 8px; color: rgba(255,255,255,.82); font-size: 11px; line-height: 1.45; }
 :global(.charge-definition-editor .editor-toolbar) { padding: 3px 5px; background: rgba(255,255,255,.025); }
 :global(.charge-definition-editor .toolbar-btn) { width: 22px; height: 22px; font-size: 10px; }
 :global(.charge-editor-content) { min-height: 94px; outline: none; }
 :global(.charge-editor-content p) { margin: 0 0 6px; }
</style>
