<script lang="ts">
	import type { CaseAttachment, CaseDetailResponse, CaseOfficerAssignment, CasePriority, CaseStatus, EvidenceItem } from "../../interfaces/ICase";

	type Tab = "overview" | "timeline" | "narrative" | "attachments" | "reports" | "evidence";

	let {
		data,
		tab = $bindable<Tab>("overview"),
		auditLogs = [],
		pagedEvidence = [],
		evidenceTotal = 0,
		onUpdateCase,
		onTogglePin,
		onDeleteCase,
		onAddNote,
		onDeleteNote,
		onLinkReport,
		onUnlinkReport,
		onAssignOfficer,
		onRemoveOfficer,
		onAddAttachment,
		onUploadAttachment,
		onRemoveAttachment,
		onAddEvidence,
		onUpdateEvidence,
		onDeleteEvidence,
		noteContent = $bindable(""),
		noteSubmitting = $bindable(false),
		reportLinkId = $bindable(""),
		officerRole = $bindable<CaseOfficerAssignment["role"]>("assisting"),
		attachmentDraft = $bindable({ type: "document" as CaseAttachment["type"], url: "", label: "" }),
		attachmentFile = $bindable<File | null>(null),
		attachmentError = $bindable(""),
		evidenceDraft = $bindable({ title: "", type: "Physical", serial: "", notes: "", location: "", stashId: "", stored: false }),
		evidenceError = $bindable(""),
	}: {
		data: CaseDetailResponse;
		tab?: Tab;
		auditLogs?: any[];
		pagedEvidence?: EvidenceItem[];
		evidenceTotal?: number;
		onUpdateCase: (update: Record<string, unknown>) => void;
		onTogglePin: () => void;
		onDeleteCase: () => void;
		onAddNote: () => void;
		onDeleteNote: (id: number) => void;
		onLinkReport: () => void;
		onUnlinkReport: (id: number) => void;
		onAssignOfficer: () => void;
		onRemoveOfficer: (citizenid: string) => void;
		onAddAttachment: () => void;
		onUploadAttachment: () => void;
		onRemoveAttachment: (id: number) => void;
		onAddEvidence: () => void;
		onUpdateEvidence: (id: number, update: Record<string, unknown>) => void;
		onDeleteEvidence: (id: number) => void;
		noteContent?: string; noteSubmitting?: boolean; reportLinkId?: string;
		officerRole?: CaseOfficerAssignment["role"];
		attachmentDraft?: { type: CaseAttachment["type"]; url: string; label: string };
		attachmentFile?: File | null; attachmentError?: string;
		evidenceDraft?: { title: string; type: string; serial: string; notes: string; location: string; stashId: string; stored: boolean };
		evidenceError?: string;
	} = $props();

	const tabs: Array<{ id: Tab; label: string }> = [
		{ id: "overview", label: "Overview" }, { id: "timeline", label: "Timeline" },
		{ id: "narrative", label: "Narrative" }, { id: "attachments", label: "Attachments" },
		{ id: "reports", label: "Reports" }, { id: "evidence", label: "Evidence" },
	];
	const statuses: CaseStatus[] = ["open", "in_progress", "closed"];
	const priorities: CasePriority[] = ["low", "medium", "high"];
	let timelineFilter = $state("all");
	let evidenceView = $state<"list" | "cards">("list");
	let evidenceQuery = $state("");
	let evidenceStorageFilter = $state<"all" | "stored" | "not_stored">("all");

	let reports = $derived(data.reports || []);
	let notes = $derived(data.notes || []);
	let actionTypes = $derived([...new Set(auditLogs.map((entry) => entry.action))]);
	let timeline = $derived(timelineFilter === "all" ? auditLogs : auditLogs.filter((entry) => entry.action === timelineFilter));
	let filteredEvidence = $derived(pagedEvidence.filter((item) => {
		const matchesQuery = !evidenceQuery.trim() || [item.title, item.type, item.serial, item.location, item.created_by]
			.filter(Boolean).some((value) => String(value).toLowerCase().includes(evidenceQuery.trim().toLowerCase()));
		const matchesStorage = evidenceStorageFilter === "all" || (evidenceStorageFilter === "stored" ? Boolean(item.stored) : !item.stored);
		return matchesQuery && matchesStorage;
	}));

	function pretty(value: string) { return value.replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase()); }
	function date(value?: string | number) { return value ? new Date(value).toLocaleString() : "—"; }
	function relative(value?: string | number) {
		if (!value) return "—";
		const days = Math.max(0, Math.floor((Date.now() - new Date(value).getTime()) / 86400000));
		return days === 0 ? "Today" : `${days} day${days === 1 ? "" : "s"} ago`;
	}
	function actionLabel(action: string) { return pretty(action || "activity"); }
	function details(value: unknown) {
		if (!value) return "";
		try { return Object.entries(typeof value === "string" ? JSON.parse(value) : value as object).filter(([, entry]) => entry !== null && entry !== "").map(([key, entry]) => `${pretty(key)}: ${entry}`).join(" · "); }
		catch { return String(value); }
	}
	function reportTags(tags?: string | null) { return tags?.split(",").filter(Boolean) || []; }
	function evidenceImage(item: EvidenceItem) { return item.images?.[0]?.url; }
	function handleAttachmentFile(event: Event) { attachmentFile = (event.currentTarget as HTMLInputElement).files?.[0] || null; }
</script>

<div class="case-file">
	<nav class="case-tabs" aria-label="Case file sections">
		{#each tabs as item}
			<button class:active={tab === item.id} onclick={() => tab = item.id}>{item.label}</button>
		{/each}
	</nav>

	<div class="case-content">
		{#if tab === "overview"}
			<div class="overview-grid">
				<div class="overview-column">
					<section class="case-card">
						<h2>Last narrative entry</h2>
						{#if notes[0]}<article class="narrative-preview"><div><strong>{notes[0].author_name || "Unknown"}</strong><time>{date(notes[0].created_at)}</time></div><p>{notes[0].content}</p></article>{:else}<p class="empty">No narrative entries yet.</p>{/if}
					</section>
					<section class="case-card"><h2>Recent timeline</h2><div class="timeline compact">{#each auditLogs.slice(0, 10) as entry}<article><b><em class="action-badge" class:note={entry.action === "case_note_added"}>{actionLabel(entry.action)}</em></b><span>{entry.actor_name || entry.actor_citizenid || "System"} · {date(entry.created_at)}</span></article>{:else}<p class="empty">No case activity yet.</p>{/each}</div></section>
					<section class="case-card"><h2>Recent evidence</h2><div class="recent-evidence-grid">{#each pagedEvidence.slice(0, 3) as item}<article class="recent-evidence-card">{#if evidenceImage(item)}<img src={evidenceImage(item)} alt={item.images?.[0]?.label || item.title} />{:else}<div class="evidence-placeholder">▧</div>{/if}<div><b>{item.title}</b><span>{item.type} · {date(item.created_at)}</span></div></article>{:else}<p class="empty">No evidence associated.</p>{/each}</div></section>
					<section class="case-card"><h2>Recent reports</h2><div class="mini-list">{#each reports.slice(0, 3) as report}<article><b>#{report.id} · {report.title}</b><span>{report.type} · {date(report.datecreated)}</span></article>{:else}<p class="empty">No reports associated.</p>{/each}</div></section>
				</div>
				<div class="overview-column">
					<section class="case-card">
						<h2>Case details</h2>
						<div class="detail-fields">
							<label>Status<select value={data.case.status} onchange={(event) => onUpdateCase({ status: (event.currentTarget as HTMLSelectElement).value })}>{#each statuses as status}<option value={status}>{pretty(status)}</option>{/each}</select></label>
							<label>Priority<select value={data.case.priority} onchange={(event) => onUpdateCase({ priority: (event.currentTarget as HTMLSelectElement).value })}>{#each priorities as priority}<option value={priority}>{pretty(priority)}</option>{/each}</select></label>
							<label class="wide">Primary department<input value={data.case.assigned_department || ""} onchange={(event) => onUpdateCase({ department: (event.currentTarget as HTMLInputElement).value })} /></label>
						</div>
						<p class="summary">{data.case.summary || "No case summary."}</p>
						<div class="case-actions">
							<button class="button" onclick={onTogglePin}>{data.case.pinned ? "Unpin" : "Pin"}</button>
							<button class="danger" onclick={onDeleteCase}>Delete case</button>
						</div>
					</section>
					<section class="case-card"><header><h2>Assigned units</h2><div><select bind:value={officerRole}><option value="supervisor">Supervisor</option><option value="primary">Primary</option><option value="assisting">Assisting</option></select><button class="button" onclick={onAssignOfficer}>Assign unit</button></div></header><div class="unit-list">{#each data.officers as officer}<article><div><b>{officer.fullname || officer.citizenid}</b><span>{officer.rank || "Officer"}{officer.callsign ? ` · ${officer.callsign}` : ""}{officer.badge_number ? ` · ${officer.badge_number}` : ""}</span></div><em class:supervisor={officer.role === "supervisor"} class:primary={officer.role === "primary"}>{pretty(officer.role)}</em><button class="icon-button" onclick={() => onRemoveOfficer(officer.citizenid)} aria-label="Remove unit">×</button></article>{:else}<p class="empty">No units assigned.</p>{/each}</div></section>
					<section class="statistics"><div class="stat-time"><i>◷</i><span>Open since</span><b>{relative(data.case.created_at)}</b></div><div class="stat-update"><i>↻</i><span>Last updated</span><b>{relative(data.case.updated_at)}</b></div><div class="stat-units"><i>♙</i><span>Units assigned</span><b>{data.officers.length}</b></div><div class="stat-notes"><i>▤</i><span>Narrative entries</span><b>{notes.length}</b></div><div class="stat-evidence"><i>◈</i><span>Evidence associated</span><b>{evidenceTotal}</b></div><div class="stat-reports"><i>▣</i><span>Reports associated</span><b>{reports.length}</b></div><div class="stat-files"><i>⌁</i><span>Attachments associated</span><b>{data.attachments.length}</b></div></section>
				</div>
			</div>
		{:else if tab === "timeline"}
			<section class="case-card timeline-page"><header><h2>Case timeline</h2><select bind:value={timelineFilter}><option value="all">All actions</option>{#each actionTypes as type}<option value={type}>{actionLabel(type)}</option>{/each}</select></header><div class="timeline connected">{#each timeline as entry}<article><i class:note={entry.action === "case_note_added"}></i><div><b><em class="action-badge" class:note={entry.action === "case_note_added"}>{actionLabel(entry.action)}</em></b><span>{entry.actor_name || entry.actor_citizenid || "System"} · {date(entry.created_at)}</span>{#if details(entry.details)}<p>{details(entry.details)}</p>{/if}</div></article>{:else}<p class="empty">No matching activity.</p>{/each}</div></section>
		{:else if tab === "narrative"}
			<section class="case-card narrative-page"><h2>Add narrative entry</h2><div class="note-form"><textarea bind:value={noteContent} rows="4" placeholder="Document an update to this case..."></textarea><button class="button" disabled={!noteContent.trim() || noteSubmitting} onclick={onAddNote}>{noteSubmitting ? "Saving…" : "Add entry"}</button></div><h2>Entries</h2><div class="notes">{#each notes as note}<article><header><b>{note.author_name || "Unknown"}</b><time>{date(note.created_at)}</time><button class="icon-button" onclick={() => onDeleteNote(note.id)} aria-label="Delete entry">×</button></header><p>{note.content}</p></article>{:else}<p class="empty">No narrative entries yet.</p>{/each}</div></section>
		{:else if tab === "attachments"}
			<section class="case-card"><h2>Add attachment</h2><div class="attachment-form"><select bind:value={attachmentDraft.type}><option value="photo">Photo</option><option value="document">Document</option><option value="other">Other</option></select><input bind:value={attachmentDraft.url} placeholder="Attachment URL" /><input bind:value={attachmentDraft.label} placeholder="Label" /><button class="button" onclick={onAddAttachment}>Add link</button><input type="file" accept=".jpg,.jpeg,.png,.webp,.pdf" onchange={handleAttachmentFile} /><button class="button" onclick={onUploadAttachment} disabled={!attachmentFile}>Upload selected file</button></div>{#if attachmentError}<p class="error">{attachmentError}</p>{/if}</section><div class="attachment-grid">{#each data.attachments as attachment}<article class="attachment-card">{#if attachment.type === "photo"}<img src={attachment.url} alt={attachment.label || "Case attachment"} />{:else}<div class="document-icon">▤</div>{/if}<div><b>{attachment.label || pretty(attachment.type)}</b><a href={attachment.url} target="_blank" rel="noreferrer">{attachment.url}</a><span>{date(attachment.uploaded_at)}</span></div><button class="icon-button" onclick={() => onRemoveAttachment(attachment.id)} aria-label="Remove attachment">×</button></article>{:else}<p class="empty">No attachments associated.</p>{/each}</div>
		{:else if tab === "reports"}
			<section class="case-card"><header><h2>Associated reports</h2><div><input bind:value={reportLinkId} placeholder="Report ID" /><button class="button" onclick={onLinkReport}>Link report</button></div></header></section><div class="report-grid">{#each reports as report}<article class="report-card"><header><div><span>REPORT #{report.id}</span><h3>{report.title}</h3></div><button class="icon-button" onclick={() => onUnlinkReport(report.id)} aria-label="Unlink report">×</button></header><dl><div><dt>Author</dt><dd>{report.authorplaintext || report.author || "—"}</dd></div><div><dt>Created</dt><dd>{date(report.datecreated)}</dd></div><div><dt>Updated</dt><dd>{date(report.dateupdated)}</dd></div></dl><div class="tags">{#each reportTags(report.tags) as tag}<span>{tag}</span>{/each}</div></article>{:else}<p class="empty">No reports associated.</p>{/each}</div>
		{:else}
			<section class="case-card"><header><h2>Evidence</h2><div class="view-toggle"><button class:active={evidenceView === "list"} onclick={() => evidenceView = "list"}>List</button><button class:active={evidenceView === "cards"} onclick={() => evidenceView = "cards"}>Cards</button></div></header><div class="evidence-form"><input bind:value={evidenceDraft.title} placeholder="Title" /><input bind:value={evidenceDraft.type} placeholder="Type" /><input bind:value={evidenceDraft.location} placeholder="Location" /><button class="button" onclick={onAddEvidence} disabled={!evidenceDraft.title.trim()}>Add evidence</button></div><div class="evidence-filters"><input bind:value={evidenceQuery} placeholder="Search title, type, serial, location, collector…" /><select bind:value={evidenceStorageFilter}><option value="all">All storage states</option><option value="stored">Stored</option><option value="not_stored">Not stored</option></select></div>{#if evidenceError}<p class="error">{evidenceError}</p>{/if}</section><div class:evidence-cards={evidenceView === "cards"} class="evidence-list">{#each filteredEvidence as item}<article><div class="evidence-photo">{#if evidenceImage(item)}<img src={evidenceImage(item)} alt={item.images?.[0]?.label || item.title} />{:else}<span>▧</span>{/if}</div><div class="evidence-info"><b>{item.title}</b><span>{item.type}{item.serial ? ` · ${item.serial}` : ""}</span><dl><div><dt>Collected by</dt><dd>{item.created_by || "—"}</dd></div><div><dt>Location</dt><dd>{item.location || "—"}</dd></div><div><dt>Storage status</dt><dd>{item.stored ? "Stored" : "Not stored"}</dd></div><div><dt>Date</dt><dd>{date(item.created_at)}</dd></div></dl></div><div class="evidence-actions"><button class="button" onclick={() => onUpdateEvidence(item.id, { stored: !item.stored })}>{item.stored ? "Unstore" : "Store"}</button><button class="icon-button" onclick={() => onDeleteEvidence(item.id)} aria-label="Remove evidence">×</button></div></article>{:else}<p class="empty">No evidence matches these filters.</p>{/each}</div>
		{/if}
	</div>
</div>

<style>
	.case-file { flex: 1; min-height: 0; display: flex; flex-direction: column; overflow: hidden; }
	.case-tabs { display: flex; gap: 4px; padding: 10px 16px 0; border-bottom: 1px solid rgba(255,255,255,.06); }
	.case-tabs button, .view-toggle button { background: transparent; border: 0; color: rgba(255,255,255,.42); padding: 9px 12px; cursor: pointer; font-size: 11px; border-bottom: 2px solid transparent; }
	.case-tabs button.active, .view-toggle button.active { color: rgb(var(--accent-text-rgb)); border-color: rgb(var(--accent-rgb)); }
	.case-content { overflow: auto; padding: 16px; }
	.overview-grid { display: grid; grid-template-columns: minmax(0, 1.1fr) minmax(320px, .9fr); gap: 16px; }
	.overview-column, .attachment-grid, .report-grid { display: grid; gap: 12px; align-content: start; }
	.case-card, .attachment-card, .report-card, .evidence-list > article { background: rgba(255,255,255,.025); border: 1px solid rgba(255,255,255,.07); border-radius: 6px; padding: 14px; }
	h2 { color: rgba(255,255,255,.55); font-size: 10px; text-transform: uppercase; letter-spacing: .7px; margin: 0 0 10px; } h3 { margin: 4px 0 0; font-size: 11px; color: rgba(255,255,255,.86); } header { display:flex; justify-content:space-between; gap:10px; align-items:center; } header h2 { margin: 0; }
	b, .summary, .narrative-preview p, .notes p { color: rgba(255,255,255,.8); } span, time, .mini-list article span, .timeline article span { color: rgba(255,255,255,.38); font-size: 10px; display: block; } p { margin: 7px 0 0; font-size: 11px; line-height: 1.45; } .empty { color: rgba(255,255,255,.35); }
	.button, .danger, select, input, textarea { font: inherit; font-size: 10px; border-radius: 4px; } .button { padding: 6px 9px; background: rgba(var(--accent-rgb),.1); color: rgb(var(--accent-text-rgb)); border: 1px solid rgba(var(--accent-rgb),.25); cursor:pointer; } .button:disabled { opacity:.45; cursor:not-allowed; } .danger { padding: 7px 10px; background: rgba(239,68,68,.08); color: #fca5a5; border: 1px solid rgba(239,68,68,.2); cursor:pointer; }
	select, input, textarea { padding: 6px 8px; background: rgba(255,255,255,.035); color: rgba(255,255,255,.8); border: 1px solid rgba(255,255,255,.1); } textarea { width:100%; box-sizing:border-box; resize:vertical; }
	.detail-fields { display:grid; grid-template-columns:1fr 1fr; gap:9px; }.detail-fields label { display:flex; flex-direction:column; gap:4px; color:rgba(255,255,255,.35); font-size:9px; text-transform:uppercase; letter-spacing:.4px; }.detail-fields .wide { grid-column:span 2; }.summary { padding-top:4px; }.case-actions { display:flex; gap:6px; margin-top:8px; }
	.unit-list article, .timeline article, .mini-list article { display:flex; gap:9px; padding:8px 0; border-top:1px solid rgba(255,255,255,.05); align-items:center; }.unit-list article > div { flex:1; }.unit-list article b { display:block; font-size:11px; line-height:1.15; }.unit-list em { font-style:normal; font-size:9px; color:#93c5fd; background:rgba(59,130,246,.12); padding:3px 5px; border-radius:3px; text-transform:uppercase; }.unit-list em.supervisor { color:#fbbf24; background:rgba(245,158,11,.12); }.unit-list em.primary { color:#6ee7b7; background:rgba(16,185,129,.12); }.icon-button { background:transparent; color:rgba(255,255,255,.4); border:0; cursor:pointer; font-size:16px; padding:1px 4px; }
	.statistics { display:grid; grid-template-columns:repeat(2,1fr); gap:8px; }.statistics div { position:relative; padding:10px 10px 10px 34px; background:rgba(255,255,255,.025); border:1px solid rgba(255,255,255,.06); border-radius:5px; overflow:hidden; }.statistics i { position:absolute; left:10px; top:12px; font-style:normal; font-size:15px; }.statistics span { text-transform:uppercase; font-size:8px; letter-spacing:.5px; }.statistics b { display:block; font-size:13px; margin-top:4px; }.statistics .stat-time i { color:#fbbf24; }.statistics .stat-update i { color:#93c5fd; }.statistics .stat-units i { color:#c4b5fd; }.statistics .stat-notes i { color:#67e8f9; }.statistics .stat-evidence i { color:#fb7185; }.statistics .stat-reports i { color:#6ee7b7; }.statistics .stat-files i { color:#fdba74; }
	.timeline { margin-top:3px; }.timeline article { position:relative; align-items:flex-start; }.timeline article i { display:block; margin-top:4px; width:9px; height:9px; flex:none; border-radius:50%; background:rgb(var(--accent-rgb)); border:3px solid rgba(var(--accent-rgb),.18); box-sizing:content-box; z-index:1; }.timeline article i.note { background:#67e8f9; border-color:rgba(103,232,249,.15); }.timeline.connected article { border-top:0; padding:12px 0 12px 22px; gap:12px; }.timeline.connected article::before { content:""; position:absolute; left:6px; top:0; bottom:0; width:1px; background:rgba(255,255,255,.12); }.timeline.connected article:first-child::before { top:17px; }.timeline.connected article:last-child::before { bottom:calc(100% - 17px); }.timeline.connected article i { position:absolute; left:0; top:10px; margin:0; }.timeline article > div { flex:1; }.timeline article p { color:rgba(255,255,255,.42); }.timeline article > div > b, .evidence-info > b, .notes header b { font-size:11px; }.compact article { padding:7px 0; display:block; }.action-badge { display:inline-block; font-style:normal; color:#93c5fd; background:rgba(59,130,246,.12); border:1px solid rgba(59,130,246,.18); border-radius:3px; padding:3px 6px; font-size:9px; text-transform:uppercase; letter-spacing:.35px; }.action-badge.note { color:#67e8f9; background:rgba(103,232,249,.1); border-color:rgba(103,232,249,.18); }
	.recent-evidence-grid { display:grid; grid-template-columns:repeat(3, minmax(0,1fr)); gap:8px; }.recent-evidence-card { overflow:hidden; border:1px solid rgba(255,255,255,.07); border-radius:4px; background:rgba(255,255,255,.02); }.recent-evidence-card img, .evidence-placeholder { width:100%; aspect-ratio:16/8; object-fit:cover; display:block; }.evidence-placeholder { display:grid; place-items:center; background:rgba(255,255,255,.035); color:rgba(255,255,255,.3); font-size:23px; }.recent-evidence-card > div:last-child { padding:7px; }.recent-evidence-card b { display:block; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; font-size:10px; }
	.note-form, .attachment-form, .evidence-form { display:flex; gap:8px; flex-wrap:wrap; align-items:start; }.note-form textarea { flex:1 1 350px; }.notes { margin-top:18px; }.notes article { padding:12px 0; border-top:1px solid rgba(255,255,255,.06); }.notes header { justify-content:start; }.notes time { flex:1; }.notes p { white-space:pre-wrap; }
	.attachment-grid { grid-template-columns:repeat(auto-fill,minmax(230px,1fr)); margin-top:12px; }.attachment-card { position:relative; padding:0; overflow:hidden; }.attachment-card img { width:100%; aspect-ratio:16/9; object-fit:cover; display:block; }.attachment-card > div:not(.document-icon) { padding:10px; }.attachment-card a { display:block; font-size:10px; color:rgb(var(--accent-text-rgb)); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; margin:5px 0; }.attachment-card .icon-button { position:absolute; top:6px; right:6px; background:rgba(0,0,0,.55); }.document-icon { height:112px; display:grid; place-items:center; font-size:42px; color:rgba(255,255,255,.28); background:rgba(255,255,255,.025); }
	.report-grid { grid-template-columns:repeat(auto-fill,minmax(270px,1fr)); margin-top:12px; }.report-card header span { color:rgba(255,255,255,.32); font-size:9px; }.report-card dl, .evidence-info dl { display:grid; grid-template-columns:repeat(2,1fr); gap:8px; margin:14px 0; }.report-card dl div, .evidence-info dl div { min-width:0; } dt { color:rgba(255,255,255,.3); text-transform:uppercase; font-size:8px; letter-spacing:.4px; } dd { margin:3px 0 0; color:rgba(255,255,255,.65); font-size:10px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }.tags { display:flex; gap:4px; flex-wrap:wrap; }.tags span { color:#93c5fd; background:rgba(59,130,246,.1); padding:3px 5px; border-radius:3px; }
	.evidence-filters { display:flex; gap:8px; margin-top:10px; }.evidence-filters input { flex:1; }.evidence-list { display:grid; gap:9px; margin-top:12px; }.evidence-list > article { display:flex; gap:12px; align-items:center; }.evidence-cards { grid-template-columns:repeat(auto-fill,minmax(280px,1fr)); }.evidence-cards > article { display:block; }.evidence-photo { width:86px; height:62px; background:rgba(255,255,255,.04); display:grid; place-items:center; flex:none; overflow:hidden; }.evidence-cards .evidence-photo { width:100%; height:140px; margin-bottom:10px; }.evidence-photo img { width:100%; height:100%; object-fit:cover; }.evidence-photo span { font-size:28px; }.evidence-info { flex:1; }.evidence-info dl { margin:7px 0 0; grid-template-columns:repeat(4,1fr); }.evidence-cards .evidence-info dl { grid-template-columns:repeat(2,1fr); }.evidence-actions { display:flex; gap:5px; align-items:center; }.view-toggle { border:1px solid rgba(255,255,255,.08); border-radius:4px; overflow:hidden; }.view-toggle button { padding:5px 8px; }
	.error { color:#fca5a5; } @media(max-width:800px) { .overview-grid { grid-template-columns:1fr; }.case-content { padding:10px; }.case-tabs { overflow-x:auto; padding-inline:10px; }.case-tabs button { white-space:nowrap; }.evidence-info dl { grid-template-columns:repeat(2,1fr); }.recent-evidence-grid { grid-template-columns:1fr; }.evidence-filters { flex-direction:column; } }
</style>
