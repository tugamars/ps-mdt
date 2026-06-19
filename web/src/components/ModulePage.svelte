<script lang="ts">
    import { moduleService } from "../services/moduleService.svelte";
    import { createTabService } from "../services/tabService.svelte";
    import ModuleComponentHost from "./ModuleComponentHost.svelte";
    import { createModuleApi } from "../services/moduleApi";
    import type { AuthService } from "../services/authService.svelte";

    interface Props {
        tabService: ReturnType<typeof createTabService>;
        authService: AuthService;
    }

    let { tabService, authService }: Props = $props();

    let activeTab = $derived(tabService.getActiveInstanceTab());
    let module = $derived(moduleService.getTabByName(activeTab));
    let moduleApi = $derived(module ? createModuleApi(module.moduleId, authService) : null);

    // Dynamically import the module's compiled JavaScript component
    let componentPromise = $derived(
        module
            ? import(
                /* @vite-ignore */
                `${window.location.origin}/modules/${encodeURIComponent(module.moduleId)}/web/dist/main.js`
            )
            : null
    );
</script>

<div>
    {#if componentPromise}
        {#await componentPromise}
            <p>Loading module...</p>
        {:then moduleComponent}
            {#if module && moduleApi && moduleComponent.default}
                <ModuleComponentHost component={moduleComponent.default} tab={module} {moduleApi} />
            {/if}
        {:catch error}
            <div class="p-4 text-red-400">
                <h2 class="font-bold text-lg">Error loading module UI</h2>
                <p>Could not load the component for "{module?.name}".</p>
                <p class="text-xs mt-2">Make sure the module has been built and has a <strong>/web/dist/main.js</strong> file.</p>
                <pre class="text-xs mt-2 bg-black/20 p-2 rounded">Error: {error.message}</pre>
            </div>
        {/await}
    {:else if module}
        <div class="p-4">
            <h1>Module '{module.name}' is loaded but has no UI component specified.</h1>
        </div>
    {:else}
        <div class="p-4">
            <h1>Module not found</h1>
        </div>
    {/if}
</div>
