<script>
    import { onMount } from 'svelte';

    export let moduleApi;

    let hasTestPermission = false;
    let rows = [];
    let loading = true;
    let error = '';

    onMount(async () => {
        hasTestPermission = moduleApi.hasPermission('example_module.test');

        try {
            const result = await moduleApi.fetchNui('getRandomNumbers');
            if (result?.success === false) {
                throw new Error(result.message || 'The client callback failed');
            }
            rows = Array.isArray(result?.numbers) ? result.numbers : [];
        } catch (reason) {
            error = reason instanceof Error ? reason.message : 'Failed to load random numbers';
        } finally {
            loading = false;
        }
    });
</script>

<section class="example-module">
    <h1>Example Module</h1>

    <div class="permission-card" class:allowed={hasTestPermission}>
        <span class="status-dot"></span>
        <div>
            <strong>example_module.test</strong>
            <p>{hasTestPermission ? 'The current user has this permission.' : 'The current user does not have this permission.'}</p>
        </div>
    </div>

    <div class="table-card">
        <h2>Client callback result</h2>
        {#if loading}
            <p class="muted">Loading random numbers from the FiveM client…</p>
        {:else if error}
            <p class="error">{error}</p>
        {:else}
            <table>
                <thead><tr><th>Index</th><th>Random value</th></tr></thead>
                <tbody>
                    {#each rows as row}
                        <tr><td>{row.index}</td><td>{row.value}</td></tr>
                    {/each}
                </tbody>
            </table>
        {/if}
    </div>
</section>

<style>
    .example-module { padding: 24px; color: rgba(255,255,255,.88); }
    h1 { margin: 0 0 18px; font-size: 22px; }
    h2 { margin: 0 0 12px; font-size: 14px; }
    .permission-card, .table-card { padding: 16px; border: 1px solid rgba(255,255,255,.08); border-radius: 8px; background: rgba(255,255,255,.025); }
    .permission-card { display: flex; gap: 10px; align-items: center; margin-bottom: 16px; }
    .status-dot { width: 10px; height: 10px; border-radius: 50%; background: #ef4444; }
    .permission-card.allowed .status-dot { background: #22c55e; }
    .permission-card p, .muted { margin: 3px 0 0; font-size: 12px; color: rgba(255,255,255,.48); }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th, td { padding: 8px 10px; text-align: left; border-bottom: 1px solid rgba(255,255,255,.06); }
    th { color: rgba(255,255,255,.45); font-size: 11px; text-transform: uppercase; }
    .error { color: #f87171; }
</style>
