# MDT UI modules

Each module registers its `manifest.json` with `exports['ps-mdt']:RegisterModule(...)` from a server script. The core sends the registered tabs to the UI and adds them to a **Modules** sidebar group automatically.

```json
{
  "id": "my_module",
  "name": "My Module",
  "version": "1.0.0",
  "permissions": [
    {
      "id": "my_module.view",
      "label": "View My Module",
      "description": "Open and use the My Module pages"
    }
  ],
  "tabs": [
    {
      "id": "overview",
      "name": "My Module",
      "icon": "extension",
      "component": "module_page",
      "permissions": ["my_module.view"],
      "jobs": ["leo", "doj"],
      "group": "operations"
    }
  ]
}
```

- `id` must contain only letters, numbers, `_`, or `-` and must match the folder name.
- Tab names should be unique across the MDT.
- `icon` is a Material Icons name and defaults to `extension`.
- `permissions` on a tab is optional. With multiple entries, access is granted when the player has any one of them. Bosses retain the existing permission override.
- Top-level permissions can remain strings for compatibility, or use objects with `id`, `label`, `description`, and optional `category`. Without `category`, permissions are shown under a Settings category named after the module. Set `category` to an existing permission category ID such as `reports`, `cases`, or `management` to place it there.
- `jobs` is optional and accepts `leo`, `ems`, and/or `doj`.
- `group` controls sidebar placement. Use an existing group ID (`operations`, `records`, `personnel`, `surveillance`, `court`, or `legal`), or define a custom group with `{ "id": "tools", "label": "Special Tools", "icon": "build" }`. When omitted, the module receives its own sidebar group named after the module. Different tabs from one module may target different groups.
- A tab with neither `permissions` nor `jobs` is visible to every authorized MDT user.
- Build the Svelte entry as `modules/<module-id>/web/dist/main.js` with a default component export. The example module's Vite config is ready to copy.
- The loaded component receives the active manifest tab as a `tab` prop, which lets one module render different content for multiple tabs.
- The current module template targets Svelte 4 and is mounted through the MDT's compatibility host. Keep the example module's Svelte/Vite versions when copying it.

The sidebar/page checks are UI access control. Any server callback exposed by a module must also validate its permission server-side before reading or changing protected data.

## Module UI API

Every module component receives a `moduleApi` prop from the main MDT:

```ts
export let moduleApi;

const allowed = moduleApi.hasPermission("my_module.use_tool");
const result = await moduleApi.fetchNui("getData", { example: true });
```

`hasPermission` uses the main MDT authentication service, including its boss override. `fetchNui` is automatically scoped to the current module ID.

Register the matching callback in the module client script:

```lua
RegisterModuleNUICallback('my_module', 'getData', function(data)
    return { value = 123 }
end)
```

Handlers may return a value directly or call the provided second `reply` argument for asynchronous work. Client callbacks are not a security boundary; protected server data/actions must still be permission-checked on the server.
