<script>
  import { onMount, onDestroy } from 'svelte';

  export let moduleApi;
  export let tab;

  let caseSearchHost;
  let casePicker;
  let selectedCase = null;

  let cards = [];
  let selectedCard = null;
  let photos = [];
  let selectedPhotoKeys = [];
  let title = '';
  let notes = '';

  let dependencyAvailable = true;
  let loadingCards = true;
  let loadingPhotos = false;
  let importing = false;
  let error = '';
  let showModePrompt = false;

  $: canImport = moduleApi.hasPermission('tugamars_csi-evidence-sdcard.import');
  $: selectedPhotos = photos.filter((photo) => selectedPhotoKeys.includes(photo.key));
  $: allSelected = photos.length > 0 && selectedPhotoKeys.length === photos.length;
  $: canSubmit = canImport && selectedCase && title.trim() && selectedPhotos.length > 0 && !importing;

  onMount(() => {
    casePicker = moduleApi.ui.createCaseSearch(caseSearchHost, {
      placeholder: 'Search by case number, title, or department...',
      onSelect: (caseRecord) => {
        selectedCase = caseRecord;
        error = '';
      }
    });

    loadCards();
  });

  onDestroy(() => casePicker?.destroy());

  async function loadCards() {
    loadingCards = true;
    error = '';

    try {
      const response = await moduleApi.fetchNui('getSDCards');
      dependencyAvailable = response?.available !== false;
      cards = response?.success ? (response.cards || []) : [];

      if (!response?.success) {
        error = response?.message || 'Unable to load SD cards.';
      }

      if (selectedCard) {
        const refreshed = cards.find((card) => card.slot === selectedCard.slot);
        if (refreshed) {
          selectedCard = refreshed;
          await loadPhotos(refreshed);
        } else {
          selectedCard = null;
          photos = [];
          selectedPhotoKeys = [];
        }
      }
    } catch (reason) {
      cards = [];
      error = messageFrom(reason, 'Unable to load SD cards.');
    } finally {
      loadingCards = false;
    }
  }

  async function loadPhotos(card) {
    selectedCard = card;
    loadingPhotos = true;
    photos = [];
    selectedPhotoKeys = [];
    error = '';

    try {
      const response = await moduleApi.fetchNui('getSDCardPhotos', { slot: card.slot });
      dependencyAvailable = response?.available !== false;

      if (!response?.success) {
        throw new Error(response?.message || 'Unable to load photos from this SD card.');
      }

      photos = (response.photos || []).map((photo, index) => ({
        ...photo,
        key: `${card.slot}:${photo.id || index}:${index}`
      }));
    } catch (reason) {
      error = messageFrom(reason, 'Unable to load photos from this SD card.');
    } finally {
      loadingPhotos = false;
    }
  }

  function togglePhoto(key) {
    selectedPhotoKeys = selectedPhotoKeys.includes(key)
      ? selectedPhotoKeys.filter((selected) => selected !== key)
      : [...selectedPhotoKeys, key];
  }

  function toggleAll() {
    selectedPhotoKeys = allSelected ? [] : photos.map((photo) => photo.key);
  }

  function requestImport() {
    if (!canSubmit) return;
    if (selectedPhotos.length > 1) {
      showModePrompt = true;
      return;
    }
    importPhotos('combined');
  }

  async function importPhotos(mode) {
    if (!canSubmit) return;

    showModePrompt = false;
    importing = true;
    error = '';

    try {
      const response = await moduleApi.fetchNui('importPhotos', {
        caseId: Number(selectedCase.id),
        title: title.trim(),
        notes: notes.trim(),
        mode,
        photos: selectedPhotos.map(({ url, location, coords, time }) => ({
          url,
          location,
          coords,
          time
        }))
      });

      if (!response?.success) {
        throw new Error(response?.message || 'Photo import failed.');
      }

      const itemCount = response.evidenceIds?.length || 1;
      moduleApi.notify(
        `Imported ${response.photoCount} photo${response.photoCount === 1 ? '' : 's'} as ${itemCount} evidence item${itemCount === 1 ? '' : 's'}`,
        'success'
      );
      selectedPhotoKeys = [];
      title = '';
      notes = '';
    } catch (reason) {
      error = messageFrom(reason, 'Photo import failed.');
      moduleApi.notify(error, 'error');
    } finally {
      importing = false;
    }
  }

  function formatTime(timestamp) {
    if (!timestamp) return 'Unknown time';
    const date = new Date(Number(timestamp) * 1000);
    return Number.isNaN(date.getTime()) ? 'Unknown time' : date.toLocaleString();
  }

  function formatCoords(coords) {
    if (!coords || coords.x == null || coords.y == null) return '';
    const values = [coords.x, coords.y];
    if (coords.z != null) values.push(coords.z);
    return values.map((value) => Number(value).toFixed(1)).join(', ');
  }

  function messageFrom(reason, fallback) {
    return reason instanceof Error ? reason.message : fallback;
  }
</script>

<svelte:head>
  <link rel="stylesheet" href="/modules/tugamars_csi-evidence-sdcard/web/dist/style.css" />
</svelte:head>

<section class="module-page">
  <header class="page-header">
    <div>
      <span class="eyebrow">{tab?.name || 'Evidence tools'}</span>
      <h1>Import SD Card Photos</h1>
      <p>Select a case, an SD card, and the photos to register as case evidence.</p>
    </div>
    <button class="secondary icon-button" type="button" on:click={loadCards} disabled={loadingCards}>
      <span class="material-icons">refresh</span>
      {loadingCards ? 'Refreshing' : 'Refresh cards'}
    </button>
  </header>

  {#if !dependencyAvailable}
    <div class="notice error-notice" role="alert">
      <span class="material-icons">sd_card_alert</span>
      <div>
        <strong>SD card service unavailable</strong>
        <span>Start <code>tugamars_csi-evidence</code>, then refresh this page.</span>
      </div>
    </div>
  {:else if !canImport}
    <div class="notice warning-notice">
      <span class="material-icons">lock</span>
      <div>
        <strong>Read-only access</strong>
        <span>You need the SD Card Import permission to register photos as evidence.</span>
      </div>
    </div>
  {/if}

  {#if error}
    <div class="inline-error" role="alert">{error}</div>
  {/if}

  <div class="workspace">
    <aside class="sidebar panel">
      <div class="panel-heading">
        <div>
          <span class="step">1</span>
          <h2>SD cards</h2>
        </div>
        <span class="count">{cards.length}</span>
      </div>

      {#if loadingCards}
        <div class="empty-state"><span class="spinner"></span>Reading inventory...</div>
      {:else if cards.length === 0}
        <div class="empty-state">
          <span class="material-icons large-icon">sd_card</span>
          <strong>No SD cards found</strong>
          <span>Insert an SD card into your inventory and refresh.</span>
        </div>
      {:else}
        <div class="card-list">
          {#each cards as card}
            <button
              type="button"
              class="sd-card"
              class:active={selectedCard?.slot === card.slot}
              on:click={() => loadPhotos(card)}
            >
              <div class="sd-icon"><span class="material-icons">sd_card</span></div>
              <div class="sd-details">
                <strong>{card.label}</strong>
                <span>Inventory slot {card.slot}</span>
              </div>
              <span class="photo-count">{card.count}/{card.max}</span>
            </button>
          {/each}
        </div>
      {/if}
    </aside>

    <main class="content">
      <div class="panel case-panel">
        <div class="panel-heading compact">
          <div>
            <span class="step">2</span>
            <h2>Target case</h2>
          </div>
          {#if selectedCase}<span class="selected-badge">Selected</span>{/if}
        </div>
        <div bind:this={caseSearchHost} class="case-search"></div>
        {#if selectedCase}
          <div class="case-summary">
            <span class="material-icons">folder_open</span>
            <div>
              <strong>{selectedCase.caseNumber || selectedCase.case_number || `Case #${selectedCase.id}`}</strong>
              <span>{selectedCase.title}</span>
            </div>
          </div>
        {/if}
      </div>

      <div class="panel photos-panel">
        <div class="panel-heading">
          <div>
            <span class="step">3</span>
            <h2>Choose photos</h2>
          </div>
          {#if photos.length > 0}
            <button type="button" class="text-button" on:click={toggleAll}>
              {allSelected ? 'Clear selection' : 'Select all'}
            </button>
          {/if}
        </div>

        {#if !selectedCard}
          <div class="empty-state photos-empty">
            <span class="material-icons large-icon">arrow_back</span>
            <strong>Select an SD card</strong>
            <span>Its stored photos will appear here.</span>
          </div>
        {:else if loadingPhotos}
          <div class="empty-state photos-empty"><span class="spinner"></span>Loading photos...</div>
        {:else if photos.length === 0}
          <div class="empty-state photos-empty">
            <span class="material-icons large-icon">no_photography</span>
            <strong>This SD card is empty</strong>
          </div>
        {:else}
          <div class="photo-grid">
            {#each photos as photo}
              <button
                type="button"
                class="photo-card"
                class:selected={selectedPhotoKeys.includes(photo.key)}
                on:click={() => togglePhoto(photo.key)}
              >
                <div class="image-wrap">
                  <img src={photo.url} alt={photo.location || 'SD card photo'} loading="lazy" />
                  <span class="check"><span class="material-icons">check</span></span>
                </div>
                <div class="photo-meta">
                  <strong>{photo.location || 'Unknown location'}</strong>
                  <span>{formatTime(photo.time)}</span>
                  {#if formatCoords(photo.coords)}<span>{formatCoords(photo.coords)}</span>{/if}
                </div>
              </button>
            {/each}
          </div>
        {/if}
      </div>

      <div class="panel details-panel">
        <div class="panel-heading compact">
          <div>
            <span class="step">4</span>
            <h2>Evidence details</h2>
          </div>
          <span class="count selected-count">{selectedPhotos.length} selected</span>
        </div>

        <div class="form-grid">
          <label>
            <span>Title <em>required</em></span>
            <input bind:value={title} maxlength="100" placeholder="e.g. Scene photographs" disabled={!canImport} />
          </label>
          <label>
            <span>Type</span>
            <input value="Photos" readonly />
          </label>
          <label class="notes-field">
            <span>Notes <small>optional</small></span>
            <textarea bind:value={notes} maxlength="4000" rows="3" placeholder="Add context for these photographs..." disabled={!canImport}></textarea>
          </label>
        </div>

        <footer class="action-bar">
          <div class="ready-state">
            {#if !selectedCase}
              Select a case to continue.
            {:else if selectedPhotos.length === 0}
              Select at least one photo.
            {:else if !title.trim()}
              Enter an evidence title.
            {:else}
              Ready to import into {selectedCase.caseNumber || selectedCase.case_number || `Case #${selectedCase.id}`}.
            {/if}
          </div>
          <button type="button" class="primary icon-button" on:click={requestImport} disabled={!canSubmit}>
            <span class="material-icons">publish</span>
            {importing ? 'Importing...' : `Import ${selectedPhotos.length || ''} photo${selectedPhotos.length === 1 ? '' : 's'}`}
          </button>
        </footer>
      </div>
    </main>
  </div>
</section>

{#if showModePrompt}
  <div class="modal-backdrop" role="presentation">
    <section class="mode-modal" role="dialog" aria-modal="true" aria-labelledby="import-mode-title">
      <div class="modal-icon"><span class="material-icons">account_tree</span></div>
      <h2 id="import-mode-title">How should these photos be registered?</h2>
      <p>You selected {selectedPhotos.length} photos. Choose how they should appear in case evidence.</p>

      <div class="mode-options">
        <button type="button" on:click={() => importPhotos('individual')}>
          <span class="material-icons">filter</span>
          <div>
            <strong>Individual evidence items</strong>
            <span>Create {selectedPhotos.length} items, preserving each photo's location separately.</span>
          </div>
        </button>
        <button type="button" on:click={() => importPhotos('combined')}>
          <span class="material-icons">collections</span>
          <div>
            <strong>One evidence item</strong>
            <span>Keep all {selectedPhotos.length} photos together under the entered title.</span>
          </div>
        </button>
      </div>

      <button type="button" class="secondary cancel-button" on:click={() => (showModePrompt = false)}>Cancel</button>
    </section>
  </div>
{/if}

<style>
  :global(*) { box-sizing: border-box; }

  .module-page {
    min-height: 100%;
    padding: 16px;
    overflow-y: auto;
    font-size: 10px;
    color: var(--primary-text, rgba(255, 255, 255, 0.9));
    background: var(--card-dark-bg, #0e0f0f);
  }

  .page-header, .panel-heading, .panel-heading > div, .action-bar, .notice, .case-summary {
    display: flex;
    align-items: center;
  }

  .page-header { justify-content: space-between; gap: 12px; margin-bottom: 12px; }
  .eyebrow { color: rgba(var(--accent-text-rgb, 96, 165, 250), 0.75); font-size: 8px; font-weight: 700; letter-spacing: 0.1em; text-transform: uppercase; }
  h1 { margin: 2px 0; font-size: 16px; font-weight: 600; }
  h2 { margin: 0; font-size: 11px; font-weight: 600; }
  p { margin: 0; color: var(--muted-text, rgba(255, 255, 255, 0.42)); font-size: 10px; }

  button, input, textarea { font: inherit; }
  button { color: inherit; }
  button:disabled { cursor: not-allowed; opacity: 0.45; }
  .material-icons { font-size: 13px; }

  .icon-button { display: inline-flex; align-items: center; justify-content: center; gap: 5px; border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 3px; padding: 5px 10px; font-size: 10px; cursor: pointer; }
  .secondary { background: transparent; color: rgba(255, 255, 255, 0.55); }
  .primary { background: rgb(var(--accent-rgb, 59, 130, 246)); color: white; font-weight: 700; }

  .notice { gap: 8px; margin-bottom: 10px; padding: 7px 9px; border: 1px solid; border-radius: 4px; }
  .notice > .material-icons { font-size: 16px; }
  .notice div { display: grid; gap: 2px; }
  .notice span { font-size: 9px; }
  .error-notice { border-color: rgba(239, 68, 68, 0.35); background: rgba(239, 68, 68, 0.09); color: #fca5a5; }
  .warning-notice { border-color: rgba(245, 158, 11, 0.35); background: rgba(245, 158, 11, 0.09); color: #fcd34d; }
  code { font-size: 9px; }
  .inline-error { margin-bottom: 10px; padding: 6px 9px; border-radius: 3px; background: rgba(239, 68, 68, 0.1); color: #fca5a5; font-size: 9px; }

  .workspace { display: grid; grid-template-columns: 220px minmax(0, 1fr); align-items: start; gap: 10px; }
  .content { display: grid; gap: 10px; min-width: 0; }
  .panel { border: 1px solid var(--border-primary, rgba(255, 255, 255, 0.06)); border-radius: 4px; background: rgba(255, 255, 255, 0.015); overflow: hidden; }
  .sidebar { position: sticky; top: 0; }
  .panel-heading { justify-content: space-between; min-height: 36px; padding: 8px 10px; border-bottom: 1px solid var(--border-primary, rgba(255, 255, 255, 0.06)); }
  .panel-heading.compact { min-height: 34px; }
  .panel-heading > div { gap: 6px; }
  .step { display: grid; place-items: center; width: 17px; height: 17px; border-radius: 50%; background: rgba(var(--accent-rgb, 59, 130, 246), 0.12); color: rgba(var(--accent-text-rgb, 96, 165, 250), 0.8); font-size: 8px; font-weight: 800; }
  .count, .selected-badge { padding: 2px 6px; border-radius: 999px; background: rgba(255, 255, 255, 0.05); color: var(--muted-text, rgba(255, 255, 255, 0.45)); font-size: 8px; }
  .selected-badge { background: rgba(34, 197, 94, 0.12); color: #86efac; }

  .card-list { display: grid; padding: 5px; gap: 3px; }
  .sd-card { display: grid; grid-template-columns: auto minmax(0, 1fr) auto; align-items: center; gap: 7px; width: 100%; padding: 7px; border: 1px solid transparent; border-radius: 3px; background: transparent; text-align: left; cursor: pointer; }
  .sd-card:hover { background: rgba(255, 255, 255, 0.045); }
  .sd-card.active { border-color: rgba(var(--accent-rgb, 59, 130, 246), 0.45); background: rgba(var(--accent-rgb, 59, 130, 246), 0.1); }
  .sd-icon { display: grid; place-items: center; width: 25px; height: 29px; border-radius: 3px; background: rgba(255, 255, 255, 0.06); }
  .sd-icon .material-icons { font-size: 16px; }
  .sd-details { display: grid; gap: 2px; min-width: 0; }
  .sd-details strong, .sd-details span { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sd-details strong { font-size: 10px; }
  .sd-details span, .photo-count { color: var(--muted-text, rgba(255, 255, 255, 0.4)); font-size: 8px; }

  .empty-state { display: grid; place-items: center; gap: 4px; min-height: 120px; padding: 16px; color: var(--muted-text, rgba(255, 255, 255, 0.4)); text-align: center; font-size: 9px; }
  .empty-state strong { color: var(--primary-text, rgba(255, 255, 255, 0.86)); }
  .empty-state span { font-size: 8px; }
  .empty-state .large-icon { font-size: 24px; opacity: 0.55; }
  .spinner { width: 16px; height: 16px; border: 2px solid rgba(255, 255, 255, 0.1); border-top-color: rgba(var(--accent-rgb, 59, 130, 246), 0.65); border-radius: 50%; animation: spin 0.75s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }

  .case-search { padding: 8px 10px; font-size: 10px; }
  .case-search :global(.ps-mdt-module-search-box) { padding: 0 8px; border-radius: 3px; }
  .case-search :global(.ps-mdt-module-search-input) { min-height: 28px; font-size: 10px; }
  .case-search :global(.ps-mdt-module-search-clear) { font-size: 14px; }
  .case-search :global(.ps-mdt-module-search-results) { border-radius: 4px; }
  .case-search :global(.ps-mdt-module-search-result) { padding: 6px 8px; }
  .case-search :global(.ps-mdt-module-search-result-label) { font-size: 10px; }
  .case-search :global(.ps-mdt-module-search-result-description),
  .case-search :global(.ps-mdt-module-search-result-meta),
  .case-search :global(.ps-mdt-module-search-selected-id) { font-size: 8px; }
  .case-summary { gap: 6px; margin: 0 10px 8px; padding: 6px 8px; border-radius: 3px; background: rgba(34, 197, 94, 0.06); color: #86efac; }
  .case-summary div { display: grid; gap: 1px; }
  .case-summary strong { font-size: 9px; }
  .case-summary span { font-size: 8px; }

  .text-button { border: 0; background: transparent; color: rgba(var(--accent-text-rgb, 96, 165, 250), 0.7); font-size: 9px; cursor: pointer; }
  .photos-empty { min-height: 200px; }
  .photo-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(145px, 1fr)); gap: 7px; max-height: 350px; padding: 8px; overflow-y: auto; }
  .photo-card { min-width: 0; padding: 0; overflow: hidden; border: 1px solid var(--border-primary, rgba(255, 255, 255, 0.07)); border-radius: 4px; background: rgba(0, 0, 0, 0.15); text-align: left; cursor: pointer; }
  .photo-card:hover { border-color: rgba(255, 255, 255, 0.25); transform: translateY(-1px); }
  .photo-card.selected { border-color: rgb(var(--accent-rgb, 59, 130, 246)); box-shadow: 0 0 0 1px rgb(var(--accent-rgb, 59, 130, 246)); }
  .image-wrap { position: relative; aspect-ratio: 16 / 10; background: rgba(0, 0, 0, 0.35); }
  .image-wrap img { width: 100%; height: 100%; object-fit: cover; }
  .check { position: absolute; top: 5px; right: 5px; display: grid; place-items: center; width: 18px; height: 18px; border: 1px solid rgba(255, 255, 255, 0.45); border-radius: 50%; background: rgba(0, 0, 0, 0.45); opacity: 0; }
  .check .material-icons { font-size: 12px; }
  .photo-card.selected .check { border-color: rgb(var(--accent-rgb, 59, 130, 246)); background: rgb(var(--accent-rgb, 59, 130, 246)); opacity: 1; }
  .photo-meta { display: grid; gap: 2px; padding: 6px 7px; }
  .photo-meta strong, .photo-meta span { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .photo-meta strong { font-size: 9px; }
  .photo-meta span { color: var(--muted-text, rgba(255, 255, 255, 0.4)); font-size: 8px; }

  .form-grid { display: grid; grid-template-columns: 2fr 1fr; gap: 8px; padding: 10px; }
  label { display: grid; align-content: start; gap: 4px; }
  label > span { font-size: 9px; font-weight: 600; }
  label em { color: rgba(var(--accent-text-rgb, 96, 165, 250), 0.75); font-size: 7px; font-style: normal; font-weight: 500; }
  label small { color: var(--muted-text, rgba(255, 255, 255, 0.52)); font-weight: 400; }
  input, textarea { width: 100%; border: 1px solid var(--input-border, rgba(255, 255, 255, 0.08)); border-radius: 3px; outline: none; padding: 6px 8px; background: var(--input-bg, rgba(0, 0, 0, 0.16)); color: inherit; font-size: 10px; }
  input:focus, textarea:focus { border-color: rgb(var(--accent-rgb, 59, 130, 246)); }
  input[readonly] { color: var(--muted-text, rgba(255, 255, 255, 0.55)); }
  textarea { resize: vertical; }
  .notes-field { grid-column: 1 / -1; }
  .action-bar { justify-content: space-between; gap: 8px; padding: 8px 10px; border-top: 1px solid var(--border-primary, rgba(255, 255, 255, 0.06)); }
  .ready-state { color: var(--muted-text, rgba(255, 255, 255, 0.4)); font-size: 9px; }

  .modal-backdrop { position: fixed; inset: 0; z-index: 1000; display: grid; place-items: center; padding: 16px; background: rgba(0, 0, 0, 0.72); backdrop-filter: blur(4px); }
  .mode-modal { width: min(420px, 100%); padding: 16px; border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 5px; background: #171919; color: rgba(255, 255, 255, 0.9); box-shadow: 0 18px 60px rgba(0, 0, 0, 0.55); }
  .modal-icon { display: grid; place-items: center; width: 30px; height: 30px; margin-bottom: 8px; border-radius: 4px; background: rgba(var(--accent-rgb, 59, 130, 246), 0.12); color: rgb(var(--accent-rgb, 59, 130, 246)); }
  .modal-icon .material-icons { font-size: 18px; }
  .mode-modal h2 { margin-bottom: 4px; font-size: 14px; }
  .mode-options { display: grid; gap: 6px; margin: 12px 0 8px; }
  .mode-options button { display: grid; grid-template-columns: auto 1fr; align-items: center; gap: 8px; padding: 9px; border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 4px; background: rgba(255, 255, 255, 0.025); text-align: left; cursor: pointer; }
  .mode-options button:hover { border-color: rgba(var(--accent-rgb, 59, 130, 246), 0.65); background: rgba(var(--accent-rgb, 59, 130, 246), 0.08); }
  .mode-options button > .material-icons { color: rgb(var(--accent-rgb, 59, 130, 246)); font-size: 18px; }
  .mode-options button div { display: grid; gap: 3px; }
  .mode-options strong { font-size: 10px; }
  .mode-options span { color: rgba(255, 255, 255, 0.45); font-size: 8px; }
  .cancel-button { width: 100%; border: 0; border-radius: 3px; padding: 6px; font-size: 9px; cursor: pointer; }

  @media (max-width: 900px) {
    .workspace { grid-template-columns: 1fr; }
    .sidebar { position: static; }
    .card-list { grid-template-columns: repeat(auto-fill, minmax(210px, 1fr)); }
  }

  @media (max-width: 620px) {
    .module-page { padding: 10px; }
    .page-header, .action-bar { align-items: stretch; flex-direction: column; }
    .form-grid { grid-template-columns: 1fr; }
    .notes-field { grid-column: auto; }
  }
</style>
