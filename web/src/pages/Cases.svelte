<script lang="ts">
	import { onMount } from "svelte";
	import { isEnvBrowser } from "../utils/misc";
	import { createCaseService } from "../services/caseService.svelte";
	import { createSearchService } from "../services/searchService.svelte";
	import { fileToBase64, formatBytes } from "../services/uploadService";
	import PersonSearchModal from "../components/report-editor/PersonSearchModal.svelte";
	import Pagination from "../components/Pagination.svelte";
	import CaseFile from "../components/cases/CaseFile.svelte";
	import type { createTabService } from "../services/tabService.svelte";
	import type { MDTTab } from "../constants";
	import type {
		CaseAttachment,
		CaseDetailResponse,
		CaseOfficerAssignment,
		CaseRecord,
		CaseStatus,
		CasePriority,
	} from "../interfaces/ICase";
	import { globalNotifications } from "../services/notificationService.svelte";

	let { tabService }: { tabService?: ReturnType<typeof createTabService> } = $props();

	function navigateTo(tab: MDTTab) {
		if (!tabService) return;
		tabService.setActiveTab(tab);
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) {
			tabService.setInstanceTab(activeInstance.id, tab);
		}
	}

	const caseService = createCaseService();
	const searchService = createSearchService();

	let cases = $state<CaseRecord[]>([]);
	let pinnedCases = $state<CaseRecord[]>([]);
	let departments = $state<string[]>([]);
	const PINNED_CASES_STORAGE_KEY = "ps-mdt:pinned-cases";
	let selectedCase = $state<CaseDetailResponse | null>(null);
	let isLoading = $state(false);
	let searchQuery = $state("");
	let reportLinkId = $state("");
	let officerSearchQuery = $state("");
	let showCreatePanel = $state(false);
	let showCaseView = $state(false);
	let showOfficerSearch = $state(false);
	let officerRole = $state<CaseOfficerAssignment["role"]>("assisting");
	let isCreateDisabled = $derived.by(() => !newCase.title.trim());
	let newCase = $state({
		title: "",
		summary: "",
		status: "open" as CaseStatus,
		priority: "medium" as CasePriority,
		department: "",
	});
	let filters = $state({
		status: "" as CaseStatus | "",
		priority: "" as CasePriority | "",
		department: "",
		myCases: false,
	});
	let attachmentDraft = $state({
		type: "document" as CaseAttachment["type"],
		url: "",
		label: "",
	});
	let attachmentFile = $state<File | null>(null);
	let attachmentError = $state("");
	let noteContent = $state("");
	let noteSubmitting = $state(false);
	let caseFileTab = $state("overview");
	const maxUploadBytes = 5 * 1024 * 1024;
	const allowedAttachmentTypes = [
		"image/jpeg",
		"image/png",
		"image/webp",
		"application/pdf",
	];
	const allowedEvidenceImageTypes = ["image/jpeg", "image/png", "image/webp"];

	const statusOptions: CaseStatus[] = ["open", "in_progress", "closed"];
	const priorityOptions: CasePriority[] = ["low", "medium", "high"];

	let checklist = $state({
		primaryOfficer: false,
		attachments: false,
		reports: false,
		statusPriority: true,
	});

	onMount(async () => {
		loadPinnedCasesFromStorage();
		if (isEnvBrowser()) {
			cases = [
				{ id: 1, case_number: 'CASE-001', title: 'Fleeca Bank Armed Robbery', summary: 'Multiple suspects robbed Fleeca Bank on Hawick Ave', status: 'open', priority: 'high', assigned_department: 'Detectives', created_by: 'DET001', created_by_name: 'Det. Williams', created_at: '2026-03-15T10:30:00Z', updated_at: '2026-03-18T14:00:00Z', primary_officer_name: 'Det. Williams', primary_officer_callsign: '201' },
				{ id: 2, case_number: 'CASE-002', title: 'Vinewood Drive-by Shooting', summary: 'Drive-by shooting on Vinewood Blvd with multiple victims', status: 'in_progress', priority: 'high', assigned_department: 'Homicide', created_by: 'DET002', created_by_name: 'Det. Chen', created_at: '2026-03-14T08:15:00Z', updated_at: '2026-03-17T16:45:00Z', primary_officer_name: 'Det. Chen', primary_officer_callsign: '205' },
				{ id: 3, case_number: 'CASE-003', title: 'Vehicle Theft Ring Investigation', summary: 'Series of high-end vehicle thefts across LS', status: 'open', priority: 'medium', assigned_department: 'Auto Theft', created_by: 'SGT001', created_by_name: 'Sgt. Garcia', created_at: '2026-03-10T12:00:00Z', updated_at: '2026-03-16T09:30:00Z', primary_officer_name: 'Sgt. Garcia', primary_officer_callsign: '301' },
				{ id: 4, case_number: 'CASE-004', title: 'Noise Complaint - Recurring', summary: 'Repeated noise complaints from Vespucci Beach area', status: 'closed', priority: 'low', assigned_department: 'Patrol', created_by: 'OFC001', created_by_name: 'Ofc. Brown', created_at: '2026-03-05T18:00:00Z', updated_at: '2026-03-12T11:00:00Z', primary_officer_name: 'Ofc. Brown', primary_officer_callsign: '455' },
				{ id: 5, case_number: 'CASE-005', title: 'Drug Trafficking - Route 68', summary: 'Suspected drug operation along Route 68 corridor', status: 'in_progress', priority: 'medium', assigned_department: 'Narcotics', created_by: 'DET003', created_by_name: 'Det. Ramirez', created_at: '2026-03-08T09:00:00Z', updated_at: '2026-03-18T08:00:00Z', primary_officer_name: 'Det. Ramirez', primary_officer_callsign: '210' },
			];
			isLoading = false;
			return;
		}
		await Promise.all([loadCases(), loadDepartments()]);
	});

	async function loadDepartments() {
		departments = await caseService.getCaseDepartments();
	}

	function loadPinnedCasesFromStorage() {
		try {
			const stored = localStorage.getItem(PINNED_CASES_STORAGE_KEY);
			const parsed = stored ? JSON.parse(stored) : [];
			pinnedCases = Array.isArray(parsed)
				? parsed.filter((item): item is CaseRecord => item && typeof item.id === "number").slice(0, 4)
				: [];
		} catch {
			pinnedCases = [];
		}
	}

	function savePinnedCases() {
		localStorage.setItem(PINNED_CASES_STORAGE_KEY, JSON.stringify(pinnedCases));
	}

	async function loadCases() {
		isLoading = true;
		const activeFilters: Record<string, unknown> = {};
		if (filters.status) {
			activeFilters.status = filters.status;
		}
		if (filters.priority) {
			activeFilters.priority = filters.priority;
		}
		if (filters.department.trim()) {
			activeFilters.department = filters.department.trim();
		}
		if (filters.myCases) activeFilters.myCases = true;
		await caseService.loadCases(1, activeFilters);
		cases = caseService.state.cases;
		isLoading = false;
	}

	async function handleTogglePin() {
		if (!selectedCase) return;
		const caseId = selectedCase.case.id;
		if (selectedCase.case.pinned) {
			pinnedCases = pinnedCases.filter((item) => item.id !== caseId);
			selectedCase.case.pinned = false;
		} else {
			if (pinnedCases.length >= 4) {
				globalNotifications.error("You can pin up to 4 cases");
				return;
			}
			selectedCase.case.pinned = true;
			pinnedCases = [{ ...selectedCase.case }, ...pinnedCases];
		}
		savePinnedCases();
	}

	async function selectCase(caseId: number) {
		isLoading = true;
		const data = await caseService.getCase(caseId);
		if (data) data.case.pinned = pinnedCases.some((item) => item.id === caseId);
		selectedCase = data;
		caseFileTab = "overview";
		showCaseView = true;
		const auditResponse = data
			? await caseService.getCaseAuditLogs(caseId, 1, auditPageSize)
			: { items: [], total: 0 };
		auditLogs = auditResponse.items || [];
		auditTotal = auditResponse.total || 0;
		pagedAuditLogs = auditLogs;
		auditPage = 1;
		evidencePage = 1;
		if (data) {
			updateChecklist(data);
			const evidenceResponse = await caseService.getCaseEvidencePage(
				caseId,
				1,
				pageSize,
			);
			if (evidenceResponse.success && evidenceResponse.data) {
				pagedEvidence = evidenceResponse.data.items || [];
				evidenceTotal = evidenceResponse.data.total || 0;
			} else {
				pagedEvidence = [];
				evidenceTotal = 0;
			}
		}
		isLoading = false;
	}

	async function handleLinkReport() {
		if (!selectedCase || !reportLinkId.trim()) return;
		const result = await caseService.linkReportToCase(
			Number(reportLinkId.trim()),
			selectedCase.case.id,
		);
		if (!result.success) {
			globalNotifications.error(result.error || "Failed to link report");
			return;
		}
		reportLinkId = "";
		await selectCase(selectedCase.case.id);
		updateChecklist(selectedCase);
	}

	async function handleAddNote() {
		if (!selectedCase || !noteContent.trim() || noteSubmitting) return;
		noteSubmitting = true;
		const success = await caseService.addCaseNote(selectedCase.case.id, noteContent.trim());
		if (success) {
			noteContent = "";
			await selectCase(selectedCase.case.id);
		} else {
			globalNotifications.error("Failed to add note");
		}
		noteSubmitting = false;
	}

	async function handleDeleteNote(noteId: number) {
		if (!selectedCase) return;
		const success = await caseService.deleteCaseNote(selectedCase.case.id, noteId);
		if (success) {
			await selectCase(selectedCase.case.id);
		} else {
			globalNotifications.error("Failed to delete note");
		}
	}

	async function handleUnlinkReport(reportId: number) {
		if (!selectedCase) return;
		await caseService.unlinkReportFromCase(reportId, selectedCase.case.id);
		await selectCase(selectedCase.case.id);
		updateChecklist(selectedCase);
	}

	function updateChecklist(data: CaseDetailResponse | null) {
		if (!data) return;
		const hasPrimaryOfficer = data.officers.some(
			(officer) => officer.role === "primary",
		);
		const hasAttachments = data.attachments.length > 0;
		const reports = (data as any).reports || [];
		const hasReports = reports.length > 0;
		const hasStatusPriority = Boolean(
			data.case.status && data.case.priority,
		);
		checklist = {
			primaryOfficer: hasPrimaryOfficer,
			attachments: hasAttachments,
			reports: hasReports,
			statusPriority: hasStatusPriority,
		};
	}

	let casePage = $state(1);
	let casePerPage = $state(25);

	let allFilteredCases = $derived.by(() => {
		const query = searchQuery.trim().toLowerCase();
		if (!query) return cases;
		return cases.filter((item) => {
			return [item.case_number, item.title, item.assigned_department]
				.filter(Boolean)
				.some((value) => String(value).toLowerCase().includes(query));
		});
	});

	let filteredCaseList = $derived.by(() => {
		const start = (casePage - 1) * casePerPage;
		return allFilteredCases.slice(start, start + casePerPage);
	});

	// Reset page on search
	$effect(() => {
		searchQuery;
		casePage = 1;
	});

	async function handleCreateCase() {
		if (!newCase.title.trim()) return;
		const response = await caseService.createCase({
			title: newCase.title,
			summary: newCase.summary,
			status: newCase.status,
			priority: newCase.priority,
			department: newCase.department || undefined,
		});
		if (response.success) {
			showCreatePanel = false;
			showCaseView = true;
			newCase = {
				title: "",
				summary: "",
				status: "open",
				priority: "medium",
				department: "",
			};
			await loadCases();
			if (response.caseId) {
				await selectCase(response.caseId);
			}
		}
	}

	async function handleUpdateCase(update: Record<string, unknown>) {
		if (!selectedCase) return;
		await caseService.updateCase(selectedCase.case.id, update);
		await selectCase(selectedCase.case.id);
		await loadCases();
	}

	async function handleDeleteCase() {
		if (!selectedCase) return;
		const id = selectedCase.case.id;
		const success = await caseService.deleteCase(id);
		if (success) {
			selectedCase = null;
			showCaseView = false;
			await loadCases();
		}
	}

	function openCreatePanel() {
		selectedCase = null;
		showCreatePanel = true;
		showCaseView = true;
	}

	function closeCaseView() {
		showCreatePanel = false;
		showCaseView = false;
	}

	function formatDateValue(value: string | number | undefined): string {
		if (!value) return "-";
		const date = new Date(value);
		if (Number.isNaN(date.getTime())) return "-";
		return date.toLocaleDateString("en-US", {
			month: "2-digit",
			day: "2-digit",
			year: "numeric",
		});
	}

	function formatTimeValue(value: string | number | undefined): string {
		if (!value) return "-";
		const date = new Date(value);
		if (Number.isNaN(date.getTime())) return "-";
		return date.toLocaleTimeString("en-US", {
			hour: "2-digit",
			minute: "2-digit",
			hour12: false,
		});
	}

	async function handleOfficerSearch(query: string) {
		officerSearchQuery = query;
		if (!query.trim()) {
			searchService.clearResults();
			return;
		}
		await searchService.searchOfficers(query);
	}

	async function handleAssignOfficer(person: {
		citizenid?: string;
		id?: string;
	}) {
		if (!selectedCase) return;
		const citizenid = person.citizenid || person.id;
		if (!citizenid) return;
		await caseService.assignOfficer(
			selectedCase.case.id,
			citizenid,
			officerRole,
		);
		showOfficerSearch = false;
		searchService.clearResults();
		officerSearchQuery = "";
		await selectCase(selectedCase.case.id);
		updateChecklist(selectedCase);
	}

	async function handleRemoveOfficer(citizenid: string) {
		if (!selectedCase) return;
		await caseService.removeOfficer(selectedCase.case.id, citizenid);
		await selectCase(selectedCase.case.id);
		updateChecklist(selectedCase);
	}

	async function handleAddAttachment() {
		if (!selectedCase || !attachmentDraft.url.trim()) return;
		await caseService.addAttachment(selectedCase.case.id, {
			id: 0,
			type: attachmentDraft.type,
			url: attachmentDraft.url,
			label: attachmentDraft.label,
		});
		attachmentDraft = { type: "document", url: "", label: "" };
		await selectCase(selectedCase.case.id);
		updateChecklist(selectedCase);
	}

	async function handleUploadAttachment() {
		if (!selectedCase || !attachmentFile) return;
		attachmentError = "";
		if (attachmentFile.size > maxUploadBytes) {
			attachmentError = `File too large (max ${formatBytes(maxUploadBytes)})`;
			return;
		}
		if (!allowedAttachmentTypes.includes(attachmentFile.type)) {
			attachmentError = "Unsupported file type";
			return;
		}
		try {
			const base64 = await fileToBase64(attachmentFile);
			const response = await caseService.addAttachmentUpload(
				selectedCase.case.id,
				{
					data: base64,
					filename: attachmentFile.name,
					contentType: attachmentFile.type,
					label: attachmentDraft.label,
					type: attachmentDraft.type,
				},
			);
			if (!response.success) {
				attachmentError = "Failed to upload attachment";
				return;
			}
			attachmentFile = null;
			attachmentDraft = { type: "document", url: "", label: "" };
			await selectCase(selectedCase.case.id);
		} catch (error) {
			attachmentError = "Failed to upload attachment";
		}
	}

	async function handleRemoveAttachment(attachmentId: number) {
		if (!selectedCase) return;
		await caseService.removeAttachment(attachmentId);
		await selectCase(selectedCase.case.id);
		updateChecklist(selectedCase);
	}

	let evidenceDraft = $state({
		title: "",
		type: "Physical",
		serial: "",
		notes: "",
		location: "",
		stashId: "",
		stored: false,
	});
	let selectedEvidenceId = $state<number | null>(null);
	let evidenceCustody = $state<any[]>([]);
	let evidenceImageLabel = $state("");
	let evidenceImageFile = $state<File | null>(null);
	let evidenceError = $state("");
	let transferCitizenId = $state("");
	let transferNotes = $state("");
	const ACTION_LABELS: Record<string, string> = {
		case_created: "Created case",
		case_updated: "Updated case",
		case_deleted: "Deleted case",
		case_officer_assigned: "Assigned officer",
		case_officer_removed: "Removed officer",
		case_attachment_added: "Added attachment",
		case_attachment_uploaded: "Uploaded attachment",
		case_attachment_removed: "Removed attachment",
		evidence_added: "Added evidence",
		evidence_updated: "Updated evidence",
		evidence_deleted: "Deleted evidence",
		evidence_transferred: "Transferred evidence",
		evidence_image_added: "Added evidence image",
		evidence_image_removed: "Removed evidence image",
		evidence_linked_case: "Linked evidence to case",
		case_created_from_evidence: "Created case from evidence",
	};

	function formatAuditAction(action: string): string {
		return ACTION_LABELS[action] || action.replace(/_/g, " ");
	}

	function formatAuditDetails(details: string | null | undefined): string {
		if (!details) return "";
		try {
			const parsed = typeof details === "string" ? JSON.parse(details) : details;
			if (typeof parsed !== "object" || parsed === null) return String(details);
			const parts: string[] = [];
			for (const [key, value] of Object.entries(parsed)) {
				if (value === null || value === undefined || value === "") continue;
				const label = key.replace(/_/g, " ").replace(/([a-z])([A-Z])/g, "$1 $2");
				parts.push(`${label}: ${value}`);
			}
			return parts.join(" | ");
		} catch {
			return String(details);
		}
	}

	let auditLogs = $state<any[]>([]);
	let evidencePage = $state(1);
	let evidenceTotal = $state(0);
	let auditPage = $state(1);
	let auditTotal = $state(0);
	let pagedEvidence = $state<any[]>([]);
	let pagedAuditLogs = $state<any[]>([]);
	const pageSize = 100;
	const auditPageSize = 1000;

	async function handleAddEvidence() {
		if (!selectedCase || !evidenceDraft.title.trim()) return;
		evidenceError = "";
		const response = await caseService.addEvidenceItem(
			selectedCase.case.id,
			{
				title: evidenceDraft.title,
				type: evidenceDraft.type,
				serial: evidenceDraft.serial,
				notes: evidenceDraft.notes,
				location: evidenceDraft.location,
				stashId: evidenceDraft.stashId,
				stored: evidenceDraft.stored,
			},
		);
		if (!response.success) {
			evidenceError = "Failed to add evidence";
			return;
		}
		evidenceDraft = {
			title: "",
			type: "Physical",
			serial: "",
			notes: "",
			location: "",
			stashId: "",
			stored: false,
		};
		await selectCase(selectedCase.case.id);
		updateChecklist(selectedCase);
	}

	async function handleUpdateEvidence(
		evidenceId: number,
		update: Record<string, unknown>,
	) {
		if (!selectedCase) return;
		await caseService.updateEvidenceItem(evidenceId, update);
		await selectCase(selectedCase.case.id);
	}

	async function handleDeleteEvidence(evidenceId: number) {
		if (!selectedCase) return;
		await caseService.deleteEvidenceItem(evidenceId);
		if (selectedEvidenceId === evidenceId) {
			selectedEvidenceId = null;
			evidenceCustody = [];
		}
		await selectCase(selectedCase.case.id);
	}

	async function handleSelectEvidence(evidenceId: number) {
		selectedEvidenceId = evidenceId;
		evidenceCustody = await caseService.getEvidenceCustody(evidenceId);
	}

	function evidenceTotalPages() {
		return Math.max(1, Math.ceil(evidenceTotal / pageSize));
	}

	function auditTotalPages() {
		return Math.max(1, Math.ceil(auditTotal / auditPageSize));
	}

	async function handleTransferEvidence(toCitizenId: string, notes: string) {
		if (!selectedEvidenceId) return;
		await caseService.transferEvidenceItem(
			selectedEvidenceId,
			toCitizenId,
			notes,
		);
		await handleSelectEvidence(selectedEvidenceId);
		await selectCase(selectedCase?.case.id || 0);
	}

	async function handleUploadEvidenceImage() {
		if (!selectedEvidenceId || !evidenceImageFile) return;
		evidenceError = "";
		if (evidenceImageFile.size > maxUploadBytes) {
			evidenceError = `Image too large (max ${formatBytes(maxUploadBytes)})`;
			return;
		}
		if (!allowedEvidenceImageTypes.includes(evidenceImageFile.type)) {
			evidenceError = "Unsupported image type";
			return;
		}
		try {
			const base64 = await fileToBase64(evidenceImageFile);
			const response = await caseService.addEvidenceImage(
				selectedEvidenceId,
				{
					id: 0,
					url: "",
					label: evidenceImageLabel,
					filename: evidenceImageFile.name,
					contentType: evidenceImageFile.type,
					data: base64,
				} as any,
			);
			if (!response.success) {
				evidenceError = "Failed to upload evidence image";
				return;
			}
			evidenceImageFile = null;
			evidenceImageLabel = "";
			await selectCase(selectedCase?.case.id || 0);
		} catch (error) {
			evidenceError = "Failed to upload evidence image";
		}
	}

	async function handleRemoveEvidenceImage(imageId: number) {
		if (!selectedEvidenceId) return;
		await caseService.removeEvidenceImage(imageId);
		await selectCase(selectedCase?.case.id || 0);
	}

	function formatStatus(status: string) {
		return status.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
	}
</script>

<div class="cases-page">
	{#if showCaseView}
		<!-- ==================== CASE VIEW (Detail or Create) ==================== -->
		<div class="topbar">
			<button class="back-btn" onclick={closeCaseView}>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
				Back
			</button>
			{#if showCreatePanel}
				<span class="topbar-title">New Case</span>
			{:else if selectedCase}
				<span class="topbar-case-number">{selectedCase.case.case_number}</span>
				<span class="topbar-title">{selectedCase.case.title}</span>
				<span class="pill {selectedCase.case.status === 'open' ? 'pill-green' : selectedCase.case.status === 'in_progress' ? 'pill-blue' : 'pill-grey'}">{formatStatus(selectedCase.case.status)}</span>
				<span class="pill {selectedCase.case.priority === 'high' ? 'pill-red' : selectedCase.case.priority === 'medium' ? 'pill-orange' : 'pill-green'}">{selectedCase.case.priority}</span>
			{/if}
		</div>

		{#if showCreatePanel}
			<!-- ==================== CREATE PANEL ==================== -->
			<div class="detail-scroll">
				<div class="create-layout">
					<div class="create-main">
						<div class="section">
							<div class="section-title">Case Details</div>
							<input type="text" placeholder="Case Title" bind:value={newCase.title} class="form-input title-input" />
							<div class="field-row">
								<div class="field-group">
									<span class="field-label">Status</span>
									<select bind:value={newCase.status} class="form-select">
										{#each statusOptions as option}
											<option value={option}>{formatStatus(option)}</option>
										{/each}
									</select>
								</div>
								<div class="field-group">
									<span class="field-label">Priority</span>
									<select bind:value={newCase.priority} class="form-select">
										{#each priorityOptions as option}
											<option value={option}>{formatStatus(option)}</option>
										{/each}
									</select>
								</div>
								<div class="field-group">
									<span class="field-label">Department</span>
									<input class="form-input" bind:value={newCase.department} placeholder="Optional" />
								</div>
							</div>
							<div class="field-group" style="margin-top:12px;">
								<span class="field-label">Summary</span>
								<textarea rows="8" bind:value={newCase.summary} placeholder="Case summary and initial notes..." class="form-textarea"></textarea>
							</div>
						</div>
					</div>
					<div class="create-side">
						<div class="section">
							<div class="section-title">Checklist</div>
							<ul class="checklist">
								<li class:complete={checklist.primaryOfficer}>
									<span class="checkmark"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg></span>
									Assign primary officer
								</li>
								<li class:complete={checklist.attachments}>
									<span class="checkmark"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg></span>
									Attach evidence
								</li>
								<li class:complete={checklist.reports}>
									<span class="checkmark"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg></span>
									Attach reports
								</li>
								<li class:complete={checklist.statusPriority}>
									<span class="checkmark"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg></span>
									Set priority and status
								</li>
							</ul>
						</div>
						<div class="section">
							<div class="section-title">Next Actions</div>
							<p class="muted-text">After creation, open the case to manage officers, evidence, attachments, and audit logs.</p>
							{#if checklist.primaryOfficer && checklist.attachments && checklist.reports && checklist.statusPriority}
								<p class="muted-text">All checklist items complete.</p>
							{/if}
						</div>
						<button class="primary-btn create-btn" onclick={handleCreateCase} disabled={isCreateDisabled} type="button">Create Case</button>
					</div>
				</div>
			</div>

		{:else if selectedCase}
			<CaseFile
				data={selectedCase}
				bind:tab={caseFileTab}
				auditLogs={auditLogs}
				pagedEvidence={pagedEvidence}
				evidenceTotal={evidenceTotal}
				onUpdateCase={handleUpdateCase}
				onTogglePin={handleTogglePin}
				onDeleteCase={handleDeleteCase}
				onAddNote={handleAddNote}
				onDeleteNote={handleDeleteNote}
				onLinkReport={handleLinkReport}
				onUnlinkReport={handleUnlinkReport}
				onAssignOfficer={() => (showOfficerSearch = true)}
				onRemoveOfficer={handleRemoveOfficer}
				onAddAttachment={handleAddAttachment}
				onUploadAttachment={handleUploadAttachment}
				onRemoveAttachment={handleRemoveAttachment}
				onAddEvidence={handleAddEvidence}
				onUpdateEvidence={handleUpdateEvidence}
				onDeleteEvidence={handleDeleteEvidence}
				bind:noteContent
				bind:noteSubmitting
				bind:reportLinkId
				bind:officerRole
				bind:attachmentDraft
				bind:attachmentFile
				bind:attachmentError
				bind:evidenceDraft
				bind:evidenceError
			/>
		{:else}
			<div class="section empty-detail">
				<h3>Select a case to view details</h3>
				<p>Use the list to open a case or create a new one.</p>
			</div>
		{/if}

	{:else}
		<!-- ==================== LIST VIEW ==================== -->
		<div class="topbar">
			<div class="search-box">
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.3)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
				<input type="text" placeholder="Search cases..." bind:value={searchQuery} />
			</div>
			<select class="form-select-sm" bind:value={filters.status} onchange={loadCases}>
				<option value="">All Status</option>
				{#each statusOptions as option}
					<option value={option}>{formatStatus(option)}</option>
				{/each}
			</select>
			<select class="form-select-sm" bind:value={filters.priority} onchange={loadCases}>
				<option value="">All Priority</option>
				{#each priorityOptions as option}
					<option value={option}>{formatStatus(option)}</option>
				{/each}
			</select>
			<select class="form-select-sm" bind:value={filters.department} onchange={loadCases}>
				<option value="">All Departments</option>
				{#each departments as department}<option value={department}>{department}</option>{/each}
			</select>
			<button class:active-filter={filters.myCases} class="filter-btn" onclick={() => { filters.myCases = !filters.myCases; loadCases(); }}>My Cases</button>
			<div style="flex:1;"></div>
			<button class="action-btn" onclick={openCreatePanel}>
				<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
				New Case
			</button>
			<button class="back-btn" onclick={loadCases} disabled={isLoading}>
				<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
				Refresh
			</button>
		</div>

		<div class="list-panel">
			{#if pinnedCases.length > 0}
				<section class="pinned-cases" aria-label="Pinned cases">
					<div class="pinned-header"><span>Pinned Cases</span><small>{pinnedCases.length}/4</small></div>
					<div class="pinned-grid">
						{#each pinnedCases as item}
							<button class="pinned-card" onclick={() => selectCase(item.id)}>
								<span class="pinned-number">{item.case_number}</span><strong>{item.title}</strong>
								<span>{item.assigned_department || "No department"} · {formatStatus(item.status)}</span>
							</button>
						{/each}
					</div>
				</section>
			{/if}
			{#if isLoading && cases.length === 0}
				<div class="center-state">
					<div class="loading-spinner"></div>
					<p>Loading cases...</p>
				</div>
			{:else if filteredCaseList.length === 0}
				<div class="center-state">
					<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.2)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>
					<h3>No Cases Found</h3>
					<p>{searchQuery ? "No cases match your search criteria." : "No cases have been created yet."}</p>
					{#if !searchQuery}
						<button class="action-btn" onclick={openCreatePanel}>Create First Case</button>
					{/if}
				</div>
			{:else}
				<!-- Table Header -->
				<div class="table-header">
					<span class="col-title">Title</span>
					<span class="col-case">Case #</span>
					<span class="col-status">Status</span>
					<span class="col-priority">Priority</span>
					<span class="col-dept">Department</span>
					<span class="col-officer">Primary Officer</span>
					<span class="col-date">Created</span>
					<span class="col-date">Updated</span>
				</div>
				<div class="table-body">
					{#each filteredCaseList.slice().reverse() as item}
						<button class="table-row" onclick={() => selectCase(item.id)}>
							<span class="col-title row-title">{item.title}</span>
							<span class="col-case row-case">{item.case_number}</span>
							<span class="col-status">
								<span class="pill {item.status === 'open' ? 'pill-green' : item.status === 'in_progress' ? 'pill-blue' : 'pill-grey'}">{formatStatus(item.status)}</span>
							</span>
							<span class="col-priority">
								<span class="pill {item.priority === 'high' ? 'pill-red' : item.priority === 'medium' ? 'pill-orange' : 'pill-green'}">{item.priority}</span>
							</span>
							<span class="col-dept">{item.assigned_department || "-"}</span>
							<span class="col-officer">{item.primary_officer_callsign ? item.primary_officer_callsign + " " : ""}{item.primary_officer_name || "Unassigned"}</span>
							<span class="col-date">{formatDateValue(item.created_at)}</span>
							<span class="col-date">{formatDateValue(item.updated_at)}</span>
						</button>
					{/each}
				</div>
			{/if}
			<Pagination
				currentPage={casePage}
				totalItems={allFilteredCases.length}
				perPage={casePerPage}
				onPageChange={(p) => { casePage = p; }}
				onPerPageChange={(pp) => { casePerPage = pp; casePage = 1; }}
			/>
		</div>
	{/if}
</div>

<PersonSearchModal
	show={showOfficerSearch}
	title="Search Officers"
	searchQuery={officerSearchQuery}
	searchResults={searchService.state.results}
	onClose={() => {
		showOfficerSearch = false;
		officerSearchQuery = "";
	}}
	onSearch={handleOfficerSearch}
	onSelect={handleAssignOfficer}
/>

<style>
	/* ===== PAGE ===== */
	.cases-page {
		height: 100%;
		background: var(--card-dark-bg);
		color: rgba(255, 255, 255, 0.9);
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	/* ===== TOPBAR ===== */
	.topbar {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 0 16px;
		height: 42px;
		flex-shrink: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.topbar-title {
		color: rgba(255, 255, 255, 0.85);
		font-size: 13px;
		font-weight: 600;
	}

	.topbar-case-number {
		color: rgba(255, 255, 255, 0.3);
		font-size: 10px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.8px;
	}

	/* ===== SEARCH BOX ===== */
	.search-box {
		display: flex;
		align-items: center;
		gap: 8px;
		background: transparent;
		border: none;
		padding: 0;
		min-width: 240px;
	}

	.search-box input {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.8);
		font-size: 12px;
		padding: 0;
		outline: none;
		width: 100%;
	}

	.search-box input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	/* ===== BUTTONS ===== */
	.back-btn {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.back-btn:hover:not(:disabled) {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.back-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.action-btn {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		background: rgba(var(--accent-rgb), 0.06);
		color: rgba(var(--accent-text-rgb), 0.7);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		padding: 4px 10px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
		flex-shrink: 0;
		white-space: nowrap;
	}

	.action-btn:hover {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.primary-btn {
		background: rgba(var(--accent-rgb), 0.08);
		color: rgba(var(--accent-text-rgb), 0.8);
		border: 1px solid rgba(var(--accent-rgb), 0.12);
		border-radius: 3px;
		padding: 4px 10px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
		white-space: nowrap;
	}

	.primary-btn:hover:not(:disabled) {
		background: rgba(var(--accent-rgb), 0.14);
	}

	.primary-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.danger-btn {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		background: transparent;
		color: rgba(239, 68, 68, 0.5);
		border: 1px solid rgba(239, 68, 68, 0.1);
		border-radius: 3px;
		padding: 4px 10px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.danger-btn:hover {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(252, 165, 165, 0.8);
	}

	.remove-btn {
		display: inline-flex;
		align-items: center;
		gap: 4px;
		background: transparent;
		border: none;
		border-radius: 3px;
		padding: 3px 6px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
		cursor: pointer;
		transition: all 0.1s;
		flex-shrink: 0;
		opacity: 0;
	}

	.list-item:hover .remove-btn,
	.chip:hover .remove-btn {
		opacity: 1;
	}

	.remove-btn:hover {
		background: rgba(239, 68, 68, 0.1);
		color: rgba(252, 165, 165, 0.8);
	}

	.page-btn {
		display: inline-flex;
		align-items: center;
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 3px 8px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		cursor: pointer;
		transition: all 0.1s;
	}

	.page-btn:hover:not(:disabled) {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.page-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	/* ===== PILLS ===== */
	.pill {
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 600;
		text-transform: capitalize;
		white-space: nowrap;
	}

	.pill-red {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(248, 113, 113, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.1);
	}

	.pill-orange {
		background: rgba(245, 158, 11, 0.08);
		color: rgba(251, 191, 36, 0.8);
		border: 1px solid rgba(245, 158, 11, 0.1);
	}

	.pill-green {
		background: rgba(16, 185, 129, 0.08);
		color: rgba(52, 211, 153, 0.8);
		border: 1px solid rgba(16, 185, 129, 0.1);
	}

	.pill-blue {
		background: rgba(var(--accent-rgb), 0.08);
		color: rgba(96, 165, 250, 0.8);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
	}

	.pill-grey {
		background: rgba(107, 114, 128, 0.08);
		color: rgba(156, 163, 175, 0.8);
		border: 1px solid rgba(107, 114, 128, 0.1);
	}

	/* ===== LIST PANEL (TABLE) ===== */
	.list-panel {
		background: transparent;
		border: none;
		border-radius: 0;
		flex: 1;
		min-height: 0;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.pinned-cases {
		padding: 12px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		background: rgba(255, 255, 255, 0.015);
	}

	.pinned-header {
		display: flex;
		justify-content: space-between;
		margin-bottom: 8px;
		color: rgba(255, 255, 255, 0.58);
		font-size: 10px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}

	.pinned-header small { color: rgba(255, 255, 255, 0.35); font-size: 10px; }
	.pinned-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 8px; }
	.pinned-card {
		min-width: 0; text-align: left; padding: 9px; border-radius: 5px;
		background: rgba(var(--accent-rgb), 0.06); border: 1px solid rgba(var(--accent-rgb), 0.18);
		cursor: pointer; color: inherit;
	}
	.pinned-card:hover { background: rgba(var(--accent-rgb), 0.11); }
	.pinned-card strong, .pinned-card span { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
	.pinned-card strong { margin: 4px 0; color: rgba(255, 255, 255, 0.82); font-size: 11px; }
	.pinned-card span { color: rgba(255, 255, 255, 0.42); font-size: 9px; }
	.pinned-card .pinned-number { color: rgb(var(--accent-text-rgb)); font-weight: 600; }
	.filter-btn {
		padding: 4px 8px; border-radius: 3px; cursor: pointer; font-size: 10px;
		color: rgba(255, 255, 255, 0.55); background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.09);
	}
	.filter-btn.active-filter { color: rgb(var(--accent-text-rgb)); background: rgba(var(--accent-rgb), 0.13); border-color: rgba(var(--accent-rgb), 0.3); }

	.table-header {
		display: grid;
		grid-template-columns: 2fr 1fr 0.8fr 0.8fr 1fr 1.2fr 0.9fr 0.9fr;
		gap: 8px;
		padding: 8px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.table-header span {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}

	.table-body {
		flex: 1;
		overflow-y: auto;
	}

	.table-row {
		display: grid;
		grid-template-columns: 2fr 1fr 0.8fr 0.8fr 1fr 1.2fr 0.9fr 0.9fr;
		gap: 8px;
		padding: 7px 16px;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		background: transparent;
		width: 100%;
		text-align: left;
		cursor: pointer;
		transition: background 0.1s;
		align-items: center;
	}

	.table-row:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.table-row span {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.45);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.row-title {
		color: rgba(255, 255, 255, 0.85) !important;
		font-weight: 500;
	}

	.row-case {
		color: rgba(96, 165, 250, 0.7) !important;
		font-weight: 500;
	}

	.nav-link {
		color: rgba(var(--accent-rgb), 0.6);
		cursor: pointer;
		transition: all 0.1s;
	}

	.nav-link:hover {
		color: rgba(var(--accent-rgb), 0.9);
		text-decoration: underline;
	}

	.nav-link-sm {
		font-size: 10px;
		white-space: nowrap;
		flex-shrink: 0;
	}

	/* ===== SECTIONS (Detail/Create) ===== */
	.section {
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 0;
		padding: 12px 16px;
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.section:last-child {
		border-bottom: none;
	}

	.section-title {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		margin-bottom: 2px;
	}

	.section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 10px;
	}

	.detail-scroll {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 0;
		padding-bottom: 12px;
	}

	/* ===== FORM INPUTS ===== */
	.form-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		outline: none;
		transition: border-color 0.1s;
		width: 100%;
		box-sizing: border-box;
	}

	.form-input:focus {
		border-color: rgba(255, 255, 255, 0.1);
	}

	.form-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.form-input-sm {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		outline: none;
		width: 90px;
	}

	.form-input-sm::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.form-select {
		padding: 5px 22px 5px 8px;
		font-size: 10px;
		text-transform: capitalize;
	}

	.form-select-sm {
		padding: 4px 20px 4px 8px;
		font-size: 10px;
		color: rgba(255, 255, 255, 0.5);
	}

	.form-textarea {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		outline: none;
		resize: vertical;
		width: 100%;
		box-sizing: border-box;
		min-height: 60px;
	}

	.form-textarea:focus {
		border-color: rgba(255, 255, 255, 0.1);
	}

	.form-textarea::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.title-input {
		font-size: 14px;
		font-weight: 600;
		padding: 6px 8px;
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 0;
	}

	.title-input:focus {
		border-bottom-color: rgba(255, 255, 255, 0.1);
	}

	.file-input {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.4);
	}

	.file-input::file-selector-button {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 3px 8px;
		color: rgba(255, 255, 255, 0.5);
		font-size: 10px;
		cursor: pointer;
		margin-right: 6px;
	}

	/* ===== FIELD LAYOUT ===== */
	.field-row {
		display: flex;
		gap: 10px;
		align-items: flex-end;
		flex-wrap: wrap;
	}

	.field-group {
		display: flex;
		flex-direction: column;
		gap: 3px;
		min-width: 120px;
		flex: 1;
	}

	.field-group-actions {
		display: flex;
		flex-direction: row;
		align-items: center;
		gap: 6px;
		min-width: auto;
		flex: none;
	}

	.field-label {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.summary-text {
		color: rgba(255, 255, 255, 0.5);
		font-size: 11px;
		margin: 0;
		line-height: 1.5;
	}

	/* ===== INLINE CONTROLS ===== */
	.inline-controls {
		display: flex;
		gap: 6px;
		align-items: center;
	}

	/* ===== CHIPS ===== */
	.chip-list {
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	.chip {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 6px 0;
		border-radius: 0;
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		font-size: 11px;
	}

	.chip:last-child {
		border-bottom: none;
	}

	.chip-info {
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.chip-name {
		font-weight: 600;
		color: rgba(255, 255, 255, 0.85);
		font-size: 11px;
	}

	.chip-meta {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	.chip-role {
		text-transform: uppercase;
		font-size: 9px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.2);
		letter-spacing: 0.5px;
		margin-left: auto;
	}

	.chip-remove {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.15);
		cursor: pointer;
		padding: 2px;
		display: flex;
		align-items: center;
		opacity: 0;
		transition: opacity 0.1s;
	}

	.chip:hover .chip-remove {
		opacity: 1;
	}

	.chip-remove:hover {
		color: rgba(248, 113, 113, 0.8);
	}

	/* ===== ITEM LIST ===== */
	.item-list {
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	.list-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 10px;
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		border-radius: 0;
		padding: 6px 0;
	}

	.list-item:last-child {
		border-bottom: none;
	}

	.list-item-info {
		display: flex;
		flex-direction: column;
		gap: 1px;
		min-width: 0;
		flex: 1;
	}

	.list-item-info strong {
		color: rgba(255, 255, 255, 0.85);
		font-size: 11px;
		font-weight: 600;
	}

	.list-item-info span {
		color: rgba(255, 255, 255, 0.3);
		font-size: 10px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	/* ===== ATTACHMENT FORM ===== */
	.attachment-form {
		display: grid;
		grid-template-columns: auto 1fr 1fr auto;
		gap: 6px;
		align-items: center;
	}

	.upload-row {
		display: flex;
		flex-wrap: wrap;
		gap: 6px;
		align-items: center;
	}

	/* ===== EVIDENCE ===== */
	.evidence-form-grid {
		display: grid;
		grid-template-columns: 1fr 1fr 1fr;
		gap: 8px;
	}

	.evidence-actions-row {
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.evidence-select {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.85);
		text-align: left;
		display: flex;
		flex-direction: column;
		gap: 1px;
		cursor: pointer;
		flex: 1;
		min-width: 0;
		padding: 0;
	}

	.evidence-select strong {
		font-size: 11px;
	}

	.evidence-select span {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.3);
	}

	.evidence-actions {
		display: flex;
		gap: 4px;
		flex-shrink: 0;
	}

	.checkbox-label {
		display: flex;
		align-items: center;
		gap: 5px;
		font-size: 11px;
		color: rgba(255, 255, 255, 0.5);
		cursor: pointer;
	}

	/* ===== TRANSFER / CUSTODY ===== */
	.transfer-row {
		display: grid;
		grid-template-columns: 1fr 2fr auto;
		gap: 6px;
		align-items: center;
	}

	.custody-list {
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	.custody-item {
		display: grid;
		grid-template-columns: 100px 1fr 2fr;
		gap: 8px;
		font-size: 10px;
		color: rgba(255, 255, 255, 0.4);
		padding: 4px 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
	}

	/* ===== AUDIT ===== */
	.audit-list {
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	.audit-item {
		display: grid;
		grid-template-columns: 1.5fr 1fr 2fr;
		gap: 8px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		padding: 6px 0;
		font-size: 11px;
	}

	.audit-item strong {
		color: rgba(255, 255, 255, 0.7);
		font-size: 11px;
	}

	.audit-item span {
		display: block;
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	.audit-meta {
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.audit-meta span {
		color: rgba(255, 255, 255, 0.2) !important;
		text-transform: uppercase;
		font-size: 9px !important;
		letter-spacing: 0.3px;
	}

	.audit-details {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
		white-space: pre-wrap;
	}

	/* ===== PAGINATION ===== */
	.pagination {
		display: flex;
		justify-content: flex-end;
		align-items: center;
		gap: 6px;
		margin-top: 4px;
	}

	.page-info {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	/* ===== STATES ===== */
	.center-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		flex: 1;
		text-align: center;
		padding: 60px 20px;
	}

	.center-state h3 {
		color: rgba(255, 255, 255, 0.5);
		font-size: 14px;
		font-weight: 600;
		margin: 12px 0 4px;
	}

	.center-state p {
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
		margin: 0 0 12px;
	}

	.empty-detail {
		align-items: center;
		text-align: center;
	}

	.empty-detail h3 {
		color: rgba(255, 255, 255, 0.5);
		font-size: 14px;
		margin: 0 0 4px;
	}

	.empty-detail p {
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
		margin: 0;
	}

	.loading-spinner {
		width: 24px;
		height: 24px;
		border: 2px solid rgba(255, 255, 255, 0.06);
		border-left: 2px solid rgba(var(--accent-rgb), 0.5);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	.error-text {
		color: rgba(248, 113, 113, 0.8);
		font-size: 10px;
		margin: 0;
	}

	.muted-text {
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
		margin: 0;
	}

	/* Notes */
	.note-input-row {
		display: flex;
		gap: 8px;
		align-items: flex-start;
		margin-bottom: 8px;
	}
	.note-input-row .form-textarea {
		flex: 1;
		background: rgba(255, 255, 255, 0.05);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 4px;
		color: rgba(255, 255, 255, 0.87);
		font-size: 11px;
		padding: 6px 8px;
		resize: vertical;
		min-height: 36px;
		font-family: inherit;
	}
	.note-input-row .form-textarea:focus {
		outline: none;
		border-color: rgba(var(--accent-rgb), 0.5);
	}
	.note-input-row .action-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}
	.notes-list {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}
	.note-item {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 4px;
		padding: 8px 10px;
	}
	.note-header {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-bottom: 4px;
	}
	.note-author {
		color: rgb(var(--accent-text-rgb));
		font-size: 10px;
		font-weight: 600;
	}
	.note-date {
		color: rgba(255, 255, 255, 0.3);
		font-size: 9px;
		flex: 1;
	}
	.note-content {
		color: rgba(255, 255, 255, 0.75);
		font-size: 11px;
		margin: 0;
		white-space: pre-wrap;
		line-height: 1.4;
	}

	/* ===== CREATE LAYOUT ===== */
	.create-layout {
		display: grid;
		grid-template-columns: 2fr 1fr;
		gap: 0;
	}

	.create-main {
		display: flex;
		flex-direction: column;
		gap: 0;
		border-right: 1px solid rgba(255, 255, 255, 0.04);
	}

	.create-side {
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	.create-btn {
		width: calc(100% - 32px);
		margin: 0 16px;
		padding: 6px;
		font-size: 11px;
	}

	/* ===== CHECKLIST ===== */
	.checklist {
		list-style: none;
		padding: 0;
		margin: 0;
	}

	.checklist li {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 5px 0;
		font-size: 11px;
		color: rgba(255, 255, 255, 0.4);
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
	}

	.checklist li:last-child {
		border-bottom: none;
	}

	.checklist li.complete {
		color: rgba(52, 211, 153, 0.8);
	}

	.checkmark {
		width: 16px;
		height: 16px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 50%;
		border: 1px solid rgba(255, 255, 255, 0.08);
		background: transparent;
		color: rgba(255, 255, 255, 0.15);
		flex-shrink: 0;
		transition: all 0.15s;
	}

	.checklist li.complete .checkmark {
		background: rgba(16, 185, 129, 0.12);
		border-color: rgba(16, 185, 129, 0.3);
		color: rgba(52, 211, 153, 0.8);
	}

	/* ===== SCROLLBAR ===== */
	.table-body::-webkit-scrollbar,
	.detail-scroll::-webkit-scrollbar {
		width: 4px;
	}

	.table-body::-webkit-scrollbar-track,
	.detail-scroll::-webkit-scrollbar-track {
		background: transparent;
	}

	.table-body::-webkit-scrollbar-thumb,
	.detail-scroll::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

	/* ===== ANIMATION ===== */
	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	/* ===== RESPONSIVE ===== */
	@media (max-width: 1024px) {
		.create-layout {
			grid-template-columns: 1fr;
		}

		.create-main {
			border-right: none;
			border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		}

		.evidence-form-grid {
			grid-template-columns: 1fr 1fr;
		}
	}

	@media (max-width: 768px) {
		.pinned-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
		.table-header,
		.table-row {
			grid-template-columns: 2fr 1fr 0.8fr 0.8fr;
		}

		.col-dept,
		.col-officer,
		.col-date {
			display: none;
		}

		.attachment-form {
			grid-template-columns: 1fr;
		}

		.field-row {
			flex-direction: column;
		}

		.search-box {
			min-width: 160px;
		}

		.evidence-form-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
