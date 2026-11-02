<script lang="ts">
	import { onMount } from "svelte";

	let visible = $state(false);
	let officer = $state({ name: "Unknown Officer", callsign: "--", rank: "Officer" });
	let startedAt = $state(0);
	let now = $state(new Date());
	let timer: ReturnType<typeof setInterval> | undefined;

	onMount(() => {
		const handleMessage = (event: MessageEvent) => {
			if (event.data?.action === "showBodycamOverlay") {
				officer = { ...officer, ...(event.data.data?.officer ?? {}) };
				startedAt = event.data.data?.startedAt ?? 0;
				visible = true;
			} else if (event.data?.action === "hideBodycamOverlay") {
				visible = false;
			}
		};

		window.addEventListener("message", handleMessage);
		timer = setInterval(() => (now = new Date()), 1000);
		return () => {
			window.removeEventListener("message", handleMessage);
			if (timer) clearInterval(timer);
		};
	});

	let timestamp = $derived(now.toLocaleString([], {
		 year: "numeric", month: "2-digit", day: "2-digit",
		 hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false
	}));
</script>

{#if visible}
	<div class="bodycam-overlay" aria-live="polite">
		<div class="feed-mark"><span class="record-dot"></span> LIVE</div>
		<div class="officer-card">
			<div class="card-label">BODYCAM FEED</div>
			<div class="officer-name">{officer.name}</div>
			<div class="officer-meta"><span>{officer.rank}</span><span>#{officer.callsign}</span></div>
		</div>
		<div class="feed-footer">
			<span>{timestamp}</span>
			<span class="exit-hint">ESC <small>EXIT FEED</small></span>
		</div>
	</div>
{/if}

<style>
	.bodycam-overlay { position: fixed; inset: 0; z-index: 9999; pointer-events: none; color: #f2f5f7; font-family: Arial, sans-serif; font-size: 11px; text-shadow: 0 1px 2px #000; }
	.feed-mark { position: absolute; top: 24px; right: 28px; display: flex; align-items: center; gap: 6px; font-weight: 700; letter-spacing: 1.2px; }
	.record-dot { width: 7px; height: 7px; border-radius: 50%; background: #e34b4b; box-shadow: 0 0 7px #e34b4b; }
	.officer-card { position: absolute; top: 24px; left: 28px; min-width: 190px; padding: 9px 12px; border-left: 2px solid #d9a441; background: rgba(8, 12, 15, .72); }
	.card-label { color: #d9a441; font-size: 9px; font-weight: 700; letter-spacing: 1px; }
	.officer-name { margin-top: 3px; font-size: 14px; font-weight: 700; }
	.officer-meta { display: flex; gap: 12px; margin-top: 3px; color: rgba(255,255,255,.68); font-size: 10px; }
	.feed-footer { position: absolute; right: 28px; bottom: 24px; left: 28px; display: flex; justify-content: space-between; color: rgba(255,255,255,.72); font-variant-numeric: tabular-nums; }
	.exit-hint { color: #fff; font-weight: 700; letter-spacing: .7px; }
	.exit-hint small { margin-left: 5px; color: rgba(255,255,255,.55); font-size: 9px; font-weight: 400; }
</style>
