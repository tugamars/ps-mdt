<script>
  import { onMount, onDestroy, tick } from 'svelte';
  export let moduleApi;
  let activeTab = 'photos', caseSearchHost, casePicker, selectedCase = null, cards = [], selectedCard = null, photos = [], photoKeys = [], title = '', notes = '', loading = false, importing = false, error = '';
  let street = '', propertyNumber = '', properties = [], searchingProperties = false, interviews = [], interviewKeys = [], loadingInterviews = false;
  $: canImport = moduleApi.hasPermission('investigations-module.import');
  $: canProperties = moduleApi.hasPermission('investigations-module.property_search');
  $: canInterviews = moduleApi.hasPermission('investigations-module.interview_import');
  $: selectedPhotos = photos.filter(x => photoKeys.includes(x.key));
  $: selectedInterviews = interviews.filter(x => interviewKeys.includes(x.key));
  function mountCasePicker() { casePicker?.destroy(); casePicker = caseSearchHost ? moduleApi.ui.createCaseSearch(caseSearchHost, { placeholder: 'Search case number or title...', onSelect: x => { selectedCase = x; error = ''; } }) : null; }
  async function switchTab(tab) { if (activeTab === tab) return; casePicker?.destroy(); casePicker = null; activeTab = tab; await tick(); if (activeTab !== 'properties') mountCasePicker(); if (tab === 'interviews' && !interviews.length) loadInterviews(); }
  onMount(() => { mountCasePicker(); loadCards(); });
  onDestroy(() => casePicker?.destroy());
  const toggle = (items, key) => items.includes(key) ? items.filter(x => x !== key) : [...items, key];
  const selectAllPhotos = () => photoKeys = photoKeys.length === photos.length ? [] : photos.map(x => x.key);
  const message = (e, fallback) => e instanceof Error ? e.message : fallback;
  async function loadCards() { loading = true; try { const r = await moduleApi.fetchNui('getSDCards'); cards = r?.success ? r.cards || [] : []; if (!r?.success) error = r?.message || 'Unable to load SD cards.'; } catch(e) { error = message(e, 'Unable to load SD cards.'); } finally { loading = false; } }
  async function loadPhotos(card) { selectedCard = card; photos = []; photoKeys = []; loading = true; try { const r = await moduleApi.fetchNui('getSDCardPhotos', { slot: card.slot }); if (!r?.success) throw new Error(r?.message || 'Unable to load photos.'); photos = (r.photos || []).map((x, i) => ({ ...x, key: `${card.slot}:${x.id || i}:${i}` })); } catch(e) { error = message(e, 'Unable to load photos.'); } finally { loading = false; } }
  async function importPhotos() { if (!canImport || !selectedCase || !title.trim() || !selectedPhotos.length) return; importing = true; try { const r = await moduleApi.fetchNui('importPhotos', { caseId: +selectedCase.id, title: title.trim(), notes: notes.trim(), mode: 'combined', storageTarget: 'evidence', photos: selectedPhotos.map(({url,location,coords,time}) => ({url,location,coords,time})) }); if (!r?.success) throw new Error(r?.message || 'Photo import failed.'); moduleApi.notify(`Imported ${r.photoCount} photo(s) as case evidence`, 'success'); photoKeys=[]; title=''; notes=''; } catch(e) { error=message(e,'Photo import failed.'); } finally { importing=false; } }
  async function searchProperties() { searchingProperties=true; error=''; try { const r=await moduleApi.fetchNui('searchProperties',{street,propertyNumber}); if(!r?.success) throw new Error(r?.message||'Property search failed.'); properties=r.properties||[]; } catch(e){properties=[];error=message(e,'Property search failed.');} finally{searchingProperties=false;} }
  async function loadInterviews(){loadingInterviews=true;error='';try{const r=await moduleApi.fetchNui('getWitnessInterviews');if(!r?.success)throw new Error(r?.message||'Unable to load witness interviews.');interviews=(r.interviews||[]).map((x,i)=>({...x,key:`${x.id}:${i}`}));}catch(e){interviews=[];error=message(e,'Unable to load witness interviews.');}finally{loadingInterviews=false;}}
  async function importInterviews(){if(!canInterviews||!selectedCase||!selectedInterviews.length)return;importing=true;try{const r=await moduleApi.fetchNui('importWitnessInterviews',{caseId:+selectedCase.id,interviews:selectedInterviews.map(({slot})=>({slot}))});if(!r?.success)throw new Error(r?.message||'Interview import failed.');moduleApi.notify(`Imported ${r.interviewCount} witness interview(s) as evidence`,'success');interviewKeys=[];}catch(e){error=message(e,'Interview import failed.');}finally{importing=false;}}
</script>
<svelte:head>
  <link rel="stylesheet" href="/modules/investigations-module/web/dist/style.css" />
</svelte:head>
<section class="page">
 <header class="page-header"><span>{activeTab==='photos' ? 'SD CARD PHOTOS' : 'INVESTIGATIONS'}</span><h1>{activeTab==='photos' ? 'Import SD Card Photos' : 'Case evidence tools'}</h1><p>{activeTab==='photos' ? 'Select a case, an SD card, and the photos to register as case evidence.' : 'Find properties and import inventory evidence into an investigation.'}</p></header>
 <nav><button class:active={activeTab==='photos'} on:click={()=>switchTab('photos')}>▣ Photos</button><button class:active={activeTab==='properties'} on:click={()=>switchTab('properties')}>⌂ Property lookup</button><button class:active={activeTab==='interviews'} on:click={()=>switchTab('interviews')}>◉ Witness interviews</button></nav>
 {#if error}<div class="error">{error}</div>{/if}
 {#if activeTab==='properties'}
  <div class="panel"><h2>Property lookup</h2><p>All matching properties are shown, including vacant properties.</p>{#if !canProperties}<div class="warning">Property Search permission required.</div>{/if}<form on:submit|preventDefault={searchProperties}><label>Street name<input bind:value={street} maxlength="100" placeholder="Grove Street" disabled={!canProperties}></label><label>Property number<input bind:value={propertyNumber} maxlength="40" placeholder="123" disabled={!canProperties}></label><button class="primary" disabled={!canProperties||searchingProperties}>{searchingProperties?'Searching…':'Search'}</button></form>{#if properties.length}<div class="results">{#each properties as x}<article><div><strong>{x.apartment ? x.apartment+' — ' : ''}No. {x.propertyId}, {x.street}</strong><small>{x.region||'Unknown region'}</small></div><div><small>OCCUPANCY</small><strong class:vacant={x.vacant}>{x.ownerName}</strong><small>{x.ownerCitizenId||'No registered owner'}</small></div></article>{/each}</div>{:else if !searchingProperties}<div class="empty">Search a street to find all matching properties.</div>{/if}</div>
 {:else}
  {#if activeTab==='photos'}
   <div class="photo-workspace">
    <aside class="step-card sd-card-panel"><div class="step-heading"><span class="step-number">1</span><h2>SD cards</h2><button class="link-button" on:click={loadCards}>Refresh cards</button></div><div class="step-body">{#each cards as c}<button class:chosen={selectedCard?.slot===c.slot} class="card-row" on:click={()=>loadPhotos(c)}><span class="media-icon">▣</span><span><strong>{c.label}</strong><small>Inventory slot {c.slot}</small></span><em>{c.count}{c.max ? '/'+c.max : ''}</em></button>{:else}<div class="empty">{loading?'Reading inventory…':'No SD cards found.'}</div>{/each}</div></aside>
    <div class="photo-flow">
     <section class="step-card target-case"><div class="step-heading"><span class="step-number">2</span><h2>Target case</h2></div><div class="step-body"><div bind:this={caseSearchHost}></div>{#if selectedCase}<div class="case-summary"><strong>{selectedCase.caseNumber||selectedCase.case_number||`Case #${selectedCase.id}`} — {selectedCase.title}</strong><small>{selectedCase.status||'Open'}{selectedCase.department ? ' · '+selectedCase.department : ''}</small></div>{/if}</div></section>
     <section class="step-card photo-picker"><div class="step-heading"><span class="step-number">3</span><h2>Choose photos</h2>{#if photos.length}<button class="link-button" on:click={selectAllPhotos}>{photoKeys.length===photos.length?'Clear all':'Select all'}</button>{/if}</div><div class="step-body">{#if photos.length}<div class="photos">{#each photos as x}<button class:selected={photoKeys.includes(x.key)} on:click={()=>photoKeys=toggle(photoKeys,x.key)}><img src={x.url} alt={x.location||'Evidence photo'}><strong>{x.location||'Unknown location'}</strong><small>{x.time ? new Date(x.time * 1000).toLocaleString() : 'No timestamp'}</small></button>{/each}</div>{:else}<div class="empty">{selectedCard?(loading?'Loading photos…':'This card is empty.'):'Select an SD card.'}</div>{/if}</div></section>
     <section class="step-card evidence-details"><div class="step-heading"><span class="step-number">4</span><h2>Evidence details</h2><span class="selection-count">{selectedPhotos.length} selected</span></div><div class="step-body"><div class="details-grid"><label>Title <em>required</em><input bind:value={title} maxlength="100" placeholder="e.g. Scene photographs" disabled={!canImport}></label><label>Type<input value="Photos" readonly></label></div><label class="notes-label">Notes <em>optional</em><textarea bind:value={notes} maxlength="4000" placeholder="Add context for these photographs..." disabled={!canImport}></textarea></label></div><footer><span>{selectedCase ? 'Ready to import into the selected case.' : 'Select a case to continue.'}</span><button class="primary" on:click={importPhotos} disabled={!canImport||importing||!selectedCase||!title.trim()||!selectedPhotos.length}>{importing?'Importing…':'↥ Import photos'}</button></footer></section>
    </div>
   </div>
  {:else}
   <div class="panel case"><h2>Target case</h2><p>{selectedCase ? (selectedCase.caseNumber||selectedCase.case_number||`Case #${selectedCase.id}`)+' — '+selectedCase.title : 'Choose the case that will receive the evidence.'}</p><div bind:this={caseSearchHost}></div></div>
   <div class="panel"><h2>Witness interviews <button on:click={loadInterviews}>Refresh</button></h2><p>Forms in your inventory are added to the target case as evidence.</p>{#if !canInterviews}<div class="warning">Witness Interview Import permission required.</div>{/if}{#each interviews as x}<button class:selected={interviewKeys.includes(x.key)} class="interview" on:click={()=>interviewKeys=toggle(interviewKeys,x.key)}><strong>{x.witnessName}</strong><span>{x.role||'Witness'} {x.date ? '• '+x.date : ''}</span><p>{x.statement}</p>{#if x.address}<small>{x.address}</small>{/if}</button>{:else}<div class="empty">{loadingInterviews?'Reading inventory…':'No witness interview forms in inventory.'}</div>{/each}{#if interviews.length}<footer><span>{selectedInterviews.length} selected</span><button class="primary" on:click={importInterviews} disabled={!canInterviews||importing||!selectedCase||!selectedInterviews.length}>{importing?'Importing…':'Import selected interviews'}</button></footer>{/if}</div>
  {/if}
 {/if}
</section>
<style>
 .page,.page *{box-sizing:border-box}.page{min-height:100%;padding:18px;background:var(--card-dark-bg,#101112);color:var(--primary-text,#eee);font:11px Arial,sans-serif}header span{color:rgb(var(--accent-rgb,59,130,246));font-weight:bold;letter-spacing:.1em;font-size:9px}h1{margin:4px 0;font-size:18px}h2{margin:0 0 5px;font-size:12px}p,small{color:rgba(255,255,255,.5)}nav{display:flex;gap:5px;margin:16px 0;border-bottom:1px solid rgba(255,255,255,.1)}button{border:0;background:transparent;color:inherit;cursor:pointer;font:inherit}button:disabled{opacity:.45;cursor:not-allowed}nav button{padding:9px 12px;color:rgba(255,255,255,.6);border-bottom:2px solid transparent}nav .active{color:white;border-color:rgb(var(--accent-rgb,59,130,246));background:rgba(var(--accent-rgb,59,130,246),.1)}.panel{margin-bottom:10px;padding:12px;border:1px solid rgba(255,255,255,.1);border-radius:5px;background:rgba(255,255,255,.02)}.case>div{margin-top:10px}.error,.warning{margin:10px 0;padding:8px;border-radius:3px}.error{background:rgba(239,68,68,.15);color:#fca5a5}.warning{background:rgba(245,158,11,.12);color:#fcd34d}form,.form{display:grid;grid-template-columns:1fr 150px auto;gap:9px;align-items:end;margin-top:12px}label{display:grid;gap:4px;font-weight:bold}input,textarea{padding:7px;border:1px solid rgba(255,255,255,.12);border-radius:3px;background:#151616;color:white;font:inherit}textarea{min-height:55px}.primary{padding:8px 11px;border-radius:3px;background:rgb(var(--accent-rgb,59,130,246));color:white;font-weight:bold}.results article{display:flex;justify-content:space-between;padding:10px;border-top:1px solid rgba(255,255,255,.08)}.results article div{display:grid;gap:3px}.results article div:last-child{text-align:right}.grid{display:grid;grid-template-columns:220px 1fr;gap:10px}.row{display:flex;justify-content:space-between;width:100%;padding:8px;text-align:left}.row:hover,.row.chosen,.photos button.selected,.interview.selected{background:rgba(var(--accent-rgb,59,130,246),.13);outline:1px solid rgb(var(--accent-rgb,59,130,246))}.photos{display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:8px}.photos button{overflow:hidden;border:1px solid rgba(255,255,255,.1);border-radius:3px;text-align:left}.photos img{display:block;width:100%;aspect-ratio:16/10;object-fit:cover}.photos strong{display:block;padding:6px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.interview{display:grid;gap:3px;width:100%;margin-top:7px;padding:9px;border:1px solid rgba(255,255,255,.1);border-radius:4px;text-align:left}.interview p{margin:0;display:-webkit-box;overflow:hidden;-webkit-line-clamp:2;-webkit-box-orient:vertical}footer{display:flex;justify-content:space-between;margin-top:10px}.empty{padding:22px;text-align:center;color:rgba(255,255,255,.5)}@media(max-width:700px){.grid,form,.form{grid-template-columns:1fr}.results article{display:grid;gap:8px}.results article div:last-child{text-align:left}}
 .vacant { color: #fcd34d; }

 /* Match the MDT's card-based workspace while retaining the shared case picker. */
 .page { min-height: 100%; max-width: 1440px; margin: 0 auto; padding: 24px; font: 12px/1.4 Inter, Arial, sans-serif; }
 header { padding: 0 2px; }
 header h1 { font-size: 24px; letter-spacing: -.02em; }
 header p { font-size: 12px; margin: 0; }
 nav { gap: 14px; margin: 22px 0 18px; }
 nav button { padding: 10px 14px; font-size: 11px; font-weight: 600; }
 .panel { padding: 18px; border-radius: 8px; background: rgba(255,255,255,.025); box-shadow: 0 4px 18px rgba(0,0,0,.08); }
 .panel h2 { font-size: 13px; }
 .case { display: grid; grid-template-columns: minmax(210px, .35fr) minmax(0, 1fr); column-gap: 18px; align-items: center; }
 .case > div { margin-top: 0; }
 form, .form { gap: 12px; }
 input, textarea { padding: 9px 10px; border-radius: 5px; }
 .primary { padding: 10px 14px; border-radius: 5px; }
 input::placeholder, textarea::placeholder { color: rgba(255,255,255,.38); opacity: 1; }
 .results article { padding: 13px 4px; }
 .interview { padding: 12px; border-radius: 6px; }
 @media (max-width: 700px) { .page { padding: 16px; } .case { display: block; } .case > div { margin-top: 12px; } }

 .photo-workspace { display: grid; grid-template-columns: 286px minmax(0, 1fr); gap: 14px; align-items: start; }
 .photo-flow { display: grid; gap: 14px; min-width: 0; }
 .step-card { margin: 0; padding: 0; overflow: hidden; border: 1px solid rgba(255,255,255,.13); border-radius: 7px; background: #171818; box-shadow: none; }
 .step-heading { display: flex; align-items: center; min-height: 47px; gap: 9px; padding: 10px 14px; border-bottom: 1px solid rgba(255,255,255,.12); }
 .step-heading h2 { margin: 0; font-size: 13px; }
 .step-number { display: inline-grid; place-items: center; width: 23px; height: 23px; border-radius: 50%; background: rgba(var(--accent-rgb,59,130,246),.24); color: rgb(var(--accent-rgb,96,165,250)); font-size: 11px; font-weight: 700; }
 .step-body { padding: 12px; }
 .step-heading .link-button { margin-left: auto; color: rgb(var(--accent-rgb,96,165,250)); font-size: 12px; }
 .sd-card-panel { position: sticky; top: 10px; }
 .card-row { display: grid; grid-template-columns: 31px minmax(0,1fr) auto; width: 100%; gap: 10px; align-items: center; padding: 10px; border: 1px solid transparent; border-radius: 5px; text-align: left; }
 .card-row + .card-row { margin-top: 5px; }
 .card-row:hover, .card-row.chosen { border-color: rgba(var(--accent-rgb,59,130,246),.78); background: rgba(var(--accent-rgb,59,130,246),.13); }
 .card-row strong, .card-row small { display: block; }
 .card-row em, .selection-count { color: rgba(255,255,255,.5); font-size: 11px; font-style: normal; }
 .media-icon { display: grid; place-items: center; width: 31px; height: 38px; border-radius: 4px; background: rgba(255,255,255,.09); font-size: 17px; }
 .target-case .step-body { padding: 12px 14px; }
 .case-summary { display: grid; gap: 3px; margin-top: 8px; padding: 12px; border: 1px solid rgba(255,255,255,.1); border-radius: 5px; background: rgba(0,0,0,.14); }
 .case-summary strong { font-size: 12px; }
 .photo-picker .step-body { min-height: 220px; }
 .photos { grid-template-columns: repeat(auto-fill, minmax(170px, 1fr)); }
 .photos button { position: relative; border-radius: 5px; background: #141515; }
 .photos button small { display: block; padding: 0 8px 8px; font-size: 10px; }
 .photos button.selected { outline: 2px solid rgb(var(--accent-rgb,59,130,246)); outline-offset: -2px; }
 .evidence-details .step-body { padding: 14px; }
 .details-grid { display: grid; grid-template-columns: minmax(0, 2fr) minmax(170px, 1fr); gap: 12px; }
 .evidence-details label { font-size: 12px; }
 .evidence-details label em { color: rgb(var(--accent-rgb,96,165,250)); font-size: 10px; font-style: normal; font-weight: 400; }
 .evidence-details input, .evidence-details textarea { margin-top: 4px; background: rgba(255,255,255,.1); border-color: rgba(255,255,255,.21); }
 .notes-label { margin-top: 12px; }
 .evidence-details footer { align-items: center; margin: 0; padding: 11px 14px; border-top: 1px solid rgba(255,255,255,.12); color: rgba(255,255,255,.52); font-size: 12px; }
 @media (max-width: 880px) { .photo-workspace { grid-template-columns: 1fr; } .sd-card-panel { position: static; } .details-grid { grid-template-columns: 1fr; } }
</style>
