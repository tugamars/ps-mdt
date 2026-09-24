<script lang="ts">
	import type { Suspect } from "../../interfaces/IReportEditor";
	import PersonnelSection from "./PersonnelSection.svelte";
	import PersonnelCard from "./PersonnelCard.svelte";

	interface Props {
		suspects: Suspect[];
		onAdd: () => void;
		onRemove: (id: string) => void;
		onUpdate: (suspect: Suspect) => void;
		onIssueWarrant: (suspect: Suspect) => void;
		onCloseWarrant?: (suspect: Suspect) => void;
		onIssueBenchWarrant?: (suspect: Suspect) => void;
		onIssueBolo?: (suspect: Suspect) => void;
		onTakeMugshot?: (suspect: Suspect) => void;
		onUploadPhoto?: (suspect: Suspect) => void;
		onAddFingerprint?: (suspect: Suspect) => void;
	}

	let {
		suspects,
		onAdd,
		onRemove,
		onUpdate,
		onIssueWarrant,
		onCloseWarrant,
		onIssueBenchWarrant,
		onIssueBolo,
		onTakeMugshot,
		onUploadPhoto,
		onAddFingerprint,
	}: Props = $props();

	function updateSuspect(id: string, field: string, value: any) {
		const suspect = suspects.find((s) => s.id === id);
		if (suspect) {
			const updated = { ...suspect, [field]: value };
			onUpdate(updated);
		}
	}

	// Reserved callbacks: warning actions are currently hidden, but remain wired for future re-enablement.
	const hiddenSuspectActions = { onTakeMugshot, onUploadPhoto, onAddFingerprint };
</script>

<PersonnelSection title="Suspects" {onAdd}>
	{#each suspects as suspect}
		<PersonnelCard
			id={suspect.id}
			fullName={suspect.fullName}
			secondaryInfo={`ID: ${suspect.citizenid}`}
			notes={suspect.notes}
			{onRemove}
			onUpdate={updateSuspect}
		>
			{#snippet actions()}
				<div class="suspect-actions-row">
					<button
						class="action-btn primary"
						onclick={() => onIssueWarrant(suspect)}
						disabled={!suspect.citizenid}
						type="button"
						aria-label="Issue warrant"
					>
						Issue Warrant
					</button>
					{#if onCloseWarrant && suspect.warrantActive}
						<button
							class="action-btn"
							onclick={() => onCloseWarrant?.(suspect)}
							type="button"
							aria-label="Remove warrant"
						>
							Remove Warrant
						</button>
					{/if}
					{#if onIssueBenchWarrant}
						<button
							class="action-btn bench-warrant"
							onclick={() => onIssueBenchWarrant(suspect)}
							disabled={!suspect.citizenid}
							type="button"
							aria-label="Issue bench warrant"
						>
							Issue Bench Warrant
						</button>
					{/if}
					{#if onIssueBolo}
						<button
							class="action-btn bolo"
							onclick={() => onIssueBolo(suspect)}
							disabled={!suspect.citizenid}
							type="button"
							aria-label="Issue BOLO"
						>
							Issue BOLO
						</button>
					{/if}
				</div>
			{/snippet}
		</PersonnelCard>
	{/each}
</PersonnelSection>

<style>
	.image-warning {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 6px 10px;
		margin-bottom: 4px;
		background: rgba(245, 158, 11, 0.08);
		border: 1px solid rgba(245, 158, 11, 0.15);
		border-radius: 5px;
		font-size: 10px;
		color: rgba(251, 191, 36, 0.85);
		line-height: 1.3;
		flex-wrap: wrap;
	}

	.warning-icon {
		flex-shrink: 0;
		color: rgba(251, 191, 36, 0.7);
	}

	.image-warning strong {
		font-weight: 600;
	}

	.warning-text {
		flex: 1;
		min-width: 0;
	}

	.warning-actions {
		display: flex;
		gap: 4px;
		margin-left: auto;
	}

	.warning-action-btn {
		display: inline-flex;
		align-items: center;
		gap: 3px;
		padding: 2px 7px;
		border-radius: 3px;
		border: 1px solid rgba(251, 191, 36, 0.25);
		background: rgba(251, 191, 36, 0.1);
		color: rgba(251, 191, 36, 0.9);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		white-space: nowrap;
		transition: all 0.12s ease;
	}

	.warning-action-btn:hover:not(:disabled) {
		background: rgba(251, 191, 36, 0.2);
		border-color: rgba(251, 191, 36, 0.4);
	}

	.warning-action-btn:disabled {
		opacity: 0.35;
		cursor: default;
	}

	.warning-action-btn svg {
		flex-shrink: 0;
	}

	.suspect-actions-row {
		display: flex;
		flex-wrap: wrap;
		gap: 4px;
	}

	.suspect-actions-row :global(.action-btn.bench-warrant) {
		background: rgba(239, 68, 68, 0.08);
		border-color: rgba(239, 68, 68, 0.15);
		color: rgba(252, 129, 129, 0.85);
	}

	.suspect-actions-row :global(.action-btn.bench-warrant:hover) {
		background: rgba(239, 68, 68, 0.15);
	}

	.suspect-actions-row :global(.action-btn.bolo) {
		background: rgba(245, 158, 11, 0.08);
		border-color: rgba(245, 158, 11, 0.15);
		color: rgba(251, 191, 36, 0.85);
	}

	.suspect-actions-row :global(.action-btn.bolo:hover) {
		background: rgba(245, 158, 11, 0.15);
	}
</style>
