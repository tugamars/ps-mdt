const STORAGE_KEY = "ps-mdt-preferences";
const DEFAULT_UI_ZOOM = 130;
const MIN_UI_ZOOM = 100;
const MAX_UI_ZOOM = 200;

let uiZoom = $state(DEFAULT_UI_ZOOM);

function normalizeUiZoom(value: unknown): number {
	const numericValue = Number(value);
	if (!Number.isFinite(numericValue)) return DEFAULT_UI_ZOOM;
	return Math.min(MAX_UI_ZOOM, Math.max(MIN_UI_ZOOM, Math.round(numericValue)));
}

function publishUiZoom(): void {
	if (typeof document !== "undefined") {
		document.documentElement.style.setProperty("--ps-mdt-ui-zoom", `${uiZoom}%`);
	}
	if (typeof window !== "undefined") {
		window.dispatchEvent(new CustomEvent("ps-mdt:ui-zoom-change", { detail: { uiZoom } }));
	}
}

function load(): void {
	try {
		const saved = localStorage.getItem(STORAGE_KEY);
		if (!saved) return;
		const preferences = JSON.parse(saved);
		if (preferences.uiZoom !== undefined) {
			uiZoom = normalizeUiZoom(preferences.uiZoom);
		}
	} catch {
		// Keep the default when preferences are unavailable or invalid.
	}
	publishUiZoom();
}

function setUiZoom(value: unknown): void {
	uiZoom = normalizeUiZoom(value);
	publishUiZoom();
}

export const preferencesService = {
	get uiZoom(): number {
		return uiZoom;
	},
	load,
	setUiZoom,
};
