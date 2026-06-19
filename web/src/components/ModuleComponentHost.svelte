<script lang="ts">
    import { onMount } from "svelte";
    import type { ModuleTab } from "../services/moduleService.svelte";
    import type { ModuleApi } from "../services/moduleApi";

    interface LegacyComponent {
        $destroy?: () => void;
    }

    interface Props {
        component: new (options: { target: HTMLElement; props?: Record<string, unknown> }) => LegacyComponent;
        tab: ModuleTab;
        moduleApi: ModuleApi;
    }

    let { component, tab, moduleApi }: Props = $props();
    let target: HTMLDivElement;

    onMount(() => {
        // Module bundles currently use Svelte 4's class component API. Mounting
        // them imperatively keeps their bundled runtime isolated from Svelte 5.
        const instance = new component({
            target,
            props: { tab, moduleApi },
        });

        return () => instance.$destroy?.();
    });
</script>

<div class="module-component-host" bind:this={target}></div>

<style>
    .module-component-host {
        width: 100%;
        height: 100%;
    }
</style>
