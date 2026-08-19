import L, { CRS, Projection, Transformation } from "leaflet";
import "leaflet/dist/leaflet.css";

export interface ModuleOption {
	value: string;
	label: string;
	disabled?: boolean;
	group?: string;
}

export interface ModuleSelectOptions {
	source?: string;
	options?: ModuleOption[];
	value?: string;
	placeholder?: string;
	disabled?: boolean;
	className?: string;
	onChange?: (value: string, option?: ModuleOption) => void;
}

export interface ModuleSelectController {
	element: HTMLSelectElement;
	getValue(): string;
	setValue(value: string): void;
	setOptions(options: ModuleOption[]): void;
	destroy(): void;
}

export interface ModuleListItem {
	id: string | number;
	label: string;
	description?: string;
	icon?: string;
	meta?: string;
	disabled?: boolean;
}

export interface ModuleListOptions {
	items?: ModuleListItem[];
	emptyText?: string;
	className?: string;
	selectable?: boolean;
	selectedId?: string | number | null;
	onSelect?: (item: ModuleListItem) => void;
}

export interface ModuleListController {
	element: HTMLDivElement;
	setItems(items: ModuleListItem[]): void;
	setSelected(id: string | number | null): void;
	destroy(): void;
}

export interface ModuleMapOptions {
	center?: [number, number];
	zoom?: number;
	minZoom?: number;
	maxZoom?: number;
	zoomControl?: boolean;
	className?: string;
}

export interface ModuleMapController {
	element: HTMLDivElement;
	map: L.Map;
	toMapLatLng(coords: { x: number; y: number }): [number, number];
	setView(coords: { x: number; y: number }, zoom?: number): void;
	invalidateSize(): void;
	destroy(): void;
}

export interface ModuleSearchResponse<T> {
	items: T[];
	page: number;
	hasMore: boolean;
	message?: string;
}

export interface ModuleSearchPickerOptions<T> {
	search(query: string, options: { page: number; limit: number }): Promise<ModuleSearchResponse<T>>;
	getId(item: T): string | number;
	getLabel(item: T): string;
	getDescription?(item: T): string | undefined;
	getMeta?(item: T): string | undefined;
	placeholder?: string;
	emptyText?: string;
	minChars?: number;
	debounceMs?: number;
	limit?: number;
	className?: string;
	selected?: T | null;
	bindTo?: HTMLInputElement | null;
	inputName?: string;
	onSelect?: (item: T | null) => void;
}

export interface ModuleSearchPickerController<T> {
	element: HTMLDivElement;
	input: HTMLInputElement;
	valueInput: HTMLInputElement | null;
	getSelected(): T | null;
	getSelectedId(): string | number | null;
	setSelected(item: T | null): void;
	setQuery(query: string): void;
	search(query?: string): Promise<void>;
	clear(): void;
	destroy(): void;
}

export interface ModuleUiApi {
	createSelect(target: HTMLElement, options?: ModuleSelectOptions): ModuleSelectController;
	createList(target: HTMLElement, options?: ModuleListOptions): ModuleListController;
	createMap(target: HTMLElement, options?: ModuleMapOptions): ModuleMapController;
	createSearchPicker<T>(target: HTMLElement, options: ModuleSearchPickerOptions<T>): ModuleSearchPickerController<T>;
}

type OptionResolver = (source: string) => ModuleOption[];

const STYLE_ID = "ps-mdt-module-ui-styles";
const COORD_SCALE = 4.5;

function installStyles() {
	if (document.getElementById(STYLE_ID)) return;
	const style = document.createElement("style");
	style.id = STYLE_ID;
	style.textContent = `
		.ps-mdt-module-select {
			width: 100%; min-height: 36px; padding: 7px 32px 7px 10px;
			border: 1px solid var(--input-border, rgba(255,255,255,.2)); border-radius: 7px;
			background: var(--input-bg, rgba(255,255,255,.1)); color: var(--primary-text, rgba(255,255,255,.87));
			font: inherit; outline: none;
		}
		.ps-mdt-module-select:focus { border-color: var(--input-focus, rgb(59,130,246)); }
		.ps-mdt-module-select option { background: var(--dark-bg, #171717); color: var(--primary-text, #fff); }
		.ps-mdt-module-list { display: flex; flex-direction: column; gap: 6px; width: 100%; }
		.ps-mdt-module-list-empty { padding: 14px; text-align: center; color: var(--muted-text, rgba(255,255,255,.6)); }
		.ps-mdt-module-list-item { display: flex; align-items: center; gap: 10px; width: 100%; padding: 10px 12px;
			border: 1px solid var(--border-primary, rgba(255,255,255,.1)); border-radius: 8px;
			background: rgba(255,255,255,.025); color: var(--primary-text, rgba(255,255,255,.87)); text-align: left; }
		button.ps-mdt-module-list-item { cursor: pointer; font: inherit; }
		button.ps-mdt-module-list-item:hover { background: var(--hover-bg, rgba(255,255,255,.05)); }
		.ps-mdt-module-list-item.is-selected { border-color: rgba(var(--accent-rgb, 59,130,246),.6); background: rgba(var(--accent-rgb, 59,130,246),.12); }
		.ps-mdt-module-list-item:disabled { cursor: not-allowed; opacity: .5; }
		.ps-mdt-module-list-icon { font-family: 'Material Icons'; font-size: 20px; color: var(--muted-text, rgba(255,255,255,.6)); }
		.ps-mdt-module-list-copy { min-width: 0; flex: 1; }
		.ps-mdt-module-list-label { display: block; font-size: 13px; font-weight: 600; }
		.ps-mdt-module-list-description, .ps-mdt-module-list-meta { display: block; margin-top: 2px; font-size: 11px; color: var(--muted-text, rgba(255,255,255,.6)); }
		.ps-mdt-module-map { width: 100%; height: 100%; min-height: 240px; background: var(--card-dark-bg, #0e0f0f); }
		.ps-mdt-module-search { position: relative; width: 100%; color: var(--primary-text, rgba(255,255,255,.87)); }
		.ps-mdt-module-search-box { display: flex; align-items: center; gap: 7px; padding: 0 10px;
			border: 1px solid var(--input-border, rgba(255,255,255,.2)); border-radius: 7px;
			background: var(--input-bg, rgba(255,255,255,.1)); }
		.ps-mdt-module-search-box:focus-within { border-color: var(--input-focus, rgb(59,130,246)); }
		.ps-mdt-module-search-input { width: 100%; min-height: 36px; border: 0; outline: 0; background: transparent;
			color: inherit; font: inherit; }
		.ps-mdt-module-search-input::placeholder { color: var(--input-placeholder, rgba(255,255,255,.5)); }
		.ps-mdt-module-search-clear { padding: 2px 5px; border: 0; background: transparent; color: var(--muted-text, rgba(255,255,255,.6));
			font-size: 18px; line-height: 1; cursor: pointer; }
		.ps-mdt-module-search-results { display: flex; flex-direction: column; gap: 4px; margin-top: 5px; padding: 5px;
			border: 1px solid var(--border-primary, rgba(255,255,255,.1)); border-radius: 8px;
			background: var(--dark-bg, #171717); max-height: 280px; overflow-y: auto; }
		.ps-mdt-module-search-state { padding: 12px; text-align: center; color: var(--muted-text, rgba(255,255,255,.6)); font-size: 12px; }
		.ps-mdt-module-search-result { display: flex; align-items: center; gap: 10px; width: 100%; padding: 9px 10px;
			border: 0; border-radius: 6px; background: transparent; color: inherit; text-align: left; font: inherit; cursor: pointer; }
		.ps-mdt-module-search-result:hover { background: var(--hover-bg, rgba(255,255,255,.05)); }
		.ps-mdt-module-search-result-copy { min-width: 0; flex: 1; }
		.ps-mdt-module-search-result-label { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 13px; font-weight: 600; }
		.ps-mdt-module-search-result-description, .ps-mdt-module-search-result-meta { display: block; margin-top: 2px;
			overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--muted-text, rgba(255,255,255,.6)); font-size: 11px; }
		.ps-mdt-module-search-selected { display: flex; align-items: center; gap: 10px; margin-top: 6px; padding: 9px 10px;
			border: 1px solid rgba(var(--accent-rgb, 59,130,246),.45); border-radius: 7px;
			background: rgba(var(--accent-rgb, 59,130,246),.1); }
		.ps-mdt-module-search-selected-copy { min-width: 0; flex: 1; }
		.ps-mdt-module-search-selected-id { color: var(--muted-text, rgba(255,255,255,.6)); font-size: 11px; }
		.ps-mdt-module-search-more { width: 100%; padding: 8px; border: 0; border-radius: 6px;
			background: var(--btn-secondary, rgba(255,255,255,.1)); color: inherit; cursor: pointer; }
	`;
	document.head.appendChild(style);
}

function replaceContents(target: HTMLElement, element: HTMLElement) {
	target.replaceChildren(element);
}

function createSelect(
	target: HTMLElement,
	options: ModuleSelectOptions,
	resolveOptions: OptionResolver,
): ModuleSelectController {
	installStyles();
	const select = document.createElement("select");
	select.className = `ps-mdt-module-select${options.className ? ` ${options.className}` : ""}`;
	select.disabled = options.disabled === true;
	let currentOptions: ModuleOption[] = [];

	function render(nextOptions: ModuleOption[]) {
		currentOptions = [...nextOptions];
		select.replaceChildren();
		if (options.placeholder !== undefined) {
			const placeholder = document.createElement("option");
			placeholder.value = "";
			placeholder.textContent = options.placeholder;
			select.appendChild(placeholder);
		}

		const groups = new Map<string, HTMLOptGroupElement>();
		for (const item of currentOptions) {
			const option = document.createElement("option");
			option.value = item.value;
			option.textContent = item.label;
			option.disabled = item.disabled === true;
			if (item.group) {
				let group = groups.get(item.group);
				if (!group) {
					group = document.createElement("optgroup");
					group.label = item.group;
					groups.set(item.group, group);
					select.appendChild(group);
				}
				group.appendChild(option);
			} else {
				select.appendChild(option);
			}
		}
	}

	const initialOptions = options.options ?? (options.source ? resolveOptions(options.source) : []);
	render(initialOptions);
	if (options.value !== undefined) select.value = options.value;

	const handleChange = () => {
		const option = currentOptions.find((item) => item.value === select.value);
		options.onChange?.(select.value, option);
	};
	select.addEventListener("change", handleChange);
	replaceContents(target, select);

	return {
		element: select,
		getValue: () => select.value,
		setValue(value) {
			select.value = value;
		},
		setOptions(nextOptions) {
			const value = select.value;
			render(nextOptions);
			select.value = value;
		},
		destroy() {
			select.removeEventListener("change", handleChange);
			select.remove();
		},
	};
}

function createList(target: HTMLElement, options: ModuleListOptions): ModuleListController {
	installStyles();
	const list = document.createElement("div");
	list.className = `ps-mdt-module-list${options.className ? ` ${options.className}` : ""}`;
	let items = options.items ?? [];
	let selectedId = options.selectedId ?? null;

	function render() {
		list.replaceChildren();
		if (items.length === 0) {
			const empty = document.createElement("div");
			empty.className = "ps-mdt-module-list-empty";
			empty.textContent = options.emptyText ?? "No items";
			list.appendChild(empty);
			return;
		}

		for (const item of items) {
			const row = document.createElement(options.selectable ? "button" : "div");
			row.className = "ps-mdt-module-list-item";
			row.dataset.itemId = String(item.id);
			row.classList.toggle("is-selected", selectedId !== null && String(selectedId) === String(item.id));
			if (row instanceof HTMLButtonElement) {
				row.type = "button";
				row.disabled = item.disabled === true;
				row.addEventListener("click", () => {
					selectedId = item.id;
					render();
					options.onSelect?.(item);
				});
			}

			if (item.icon) {
				const icon = document.createElement("span");
				icon.className = "ps-mdt-module-list-icon";
				icon.textContent = item.icon;
				row.appendChild(icon);
			}
			const copy = document.createElement("span");
			copy.className = "ps-mdt-module-list-copy";
			const label = document.createElement("span");
			label.className = "ps-mdt-module-list-label";
			label.textContent = item.label;
			copy.appendChild(label);
			if (item.description) {
				const description = document.createElement("span");
				description.className = "ps-mdt-module-list-description";
				description.textContent = item.description;
				copy.appendChild(description);
			}
			row.appendChild(copy);
			if (item.meta) {
				const meta = document.createElement("span");
				meta.className = "ps-mdt-module-list-meta";
				meta.textContent = item.meta;
				row.appendChild(meta);
			}
			list.appendChild(row);
		}
	}

	render();
	replaceContents(target, list);
	return {
		element: list,
		setItems(nextItems) {
			items = [...nextItems];
			render();
		},
		setSelected(id) {
			selectedId = id;
			render();
		},
		destroy() {
			list.remove();
		},
	};
}

function createSearchPicker<T>(
	target: HTMLElement,
	options: ModuleSearchPickerOptions<T>,
): ModuleSearchPickerController<T> {
	installStyles();
	const root = document.createElement("div");
	root.className = `ps-mdt-module-search${options.className ? ` ${options.className}` : ""}`;
	const searchBox = document.createElement("div");
	searchBox.className = "ps-mdt-module-search-box";
	const input = document.createElement("input");
	input.type = "search";
	input.autocomplete = "off";
	input.className = "ps-mdt-module-search-input";
	input.placeholder = options.placeholder ?? "Search...";
	const clearButton = document.createElement("button");
	clearButton.type = "button";
	clearButton.className = "ps-mdt-module-search-clear";
	clearButton.setAttribute("aria-label", "Clear selection and search");
	clearButton.textContent = "×";
	searchBox.append(input, clearButton);
	const selectedElement = document.createElement("div");
	const resultsElement = document.createElement("div");
	resultsElement.className = "ps-mdt-module-search-results";
	resultsElement.hidden = true;
	root.append(searchBox, selectedElement, resultsElement);

	let valueInput = options.bindTo ?? null;
	if (!valueInput && options.inputName) {
		valueInput = document.createElement("input");
		valueInput.type = "hidden";
		valueInput.name = options.inputName;
		root.appendChild(valueInput);
	}

	let selected: T | null = options.selected === undefined ? null : options.selected;
	let items: T[] = [];
	let page = 1;
	let hasMore = false;
	let loading = false;
	let debounceTimer: ReturnType<typeof setTimeout> | null = null;
	let requestNumber = 0;
	let destroyed = false;
	const minChars = Math.max(1, options.minChars ?? 2);
	const limit = Math.max(1, options.limit ?? 10);

	function dispatchBoundValue(value: string) {
		if (!valueInput) return;
		valueInput.value = value;
		valueInput.dispatchEvent(new Event("input", { bubbles: true }));
		valueInput.dispatchEvent(new Event("change", { bubbles: true }));
	}

	function renderSelected() {
		selectedElement.replaceChildren();
		selectedElement.className = "";
		if (selected === null) return;
		selectedElement.className = "ps-mdt-module-search-selected";
		const copy = document.createElement("span");
		copy.className = "ps-mdt-module-search-selected-copy";
		const label = document.createElement("span");
		label.className = "ps-mdt-module-search-result-label";
		label.textContent = options.getLabel(selected);
		const id = document.createElement("span");
		id.className = "ps-mdt-module-search-selected-id";
		id.textContent = String(options.getId(selected));
		copy.append(label, id);
		selectedElement.appendChild(copy);
	}

	function selectItem(item: T | null, emit = true) {
		selected = item;
		dispatchBoundValue(item !== null ? String(options.getId(item)) : "");
		renderSelected();
		resultsElement.hidden = true;
		input.value = item !== null ? options.getLabel(item) : "";
		if (emit) {
			options.onSelect?.(item);
			root.dispatchEvent(new CustomEvent("select", { detail: item, bubbles: true }));
		}
	}

	function appendText(parent: HTMLElement, className: string, text?: string) {
		if (!text) return;
		const element = document.createElement("span");
		element.className = className;
		element.textContent = text;
		parent.appendChild(element);
	}

	function renderResults(message?: string) {
		resultsElement.replaceChildren();
		resultsElement.hidden = false;
		if (loading || message || items.length === 0) {
			const state = document.createElement("div");
			state.className = "ps-mdt-module-search-state";
			state.textContent = loading ? "Searching..." : message ?? options.emptyText ?? "No results found";
			resultsElement.appendChild(state);
			return;
		}

		for (const item of items) {
			const button = document.createElement("button");
			button.type = "button";
			button.className = "ps-mdt-module-search-result";
			const copy = document.createElement("span");
			copy.className = "ps-mdt-module-search-result-copy";
			appendText(copy, "ps-mdt-module-search-result-label", options.getLabel(item));
			appendText(copy, "ps-mdt-module-search-result-description", options.getDescription?.(item));
			button.appendChild(copy);
			appendText(button, "ps-mdt-module-search-result-meta", options.getMeta?.(item));
			button.addEventListener("click", () => selectItem(item));
			resultsElement.appendChild(button);
		}
		if (hasMore) {
			const more = document.createElement("button");
			more.type = "button";
			more.className = "ps-mdt-module-search-more";
			more.textContent = "Load more";
			more.addEventListener("click", () => runSearch(input.value, page + 1, true));
			resultsElement.appendChild(more);
		}
	}

	async function runSearch(query = input.value, nextPage = 1, append = false) {
		query = query.trim();
		if (query.length < minChars) {
			items = [];
			hasMore = false;
			if (query.length > 0) renderResults(`Enter at least ${minChars} characters`);
			else resultsElement.hidden = true;
			return;
		}
		const currentRequest = ++requestNumber;
		loading = true;
		renderResults();
		try {
			const response = await options.search(query, { page: nextPage, limit });
			if (destroyed || currentRequest !== requestNumber) return;
			items = append ? [...items, ...(response.items ?? [])] : (response.items ?? []);
			page = response.page ?? nextPage;
			hasMore = response.hasMore === true;
			loading = false;
			renderResults(response.message);
		} catch (reason) {
			if (destroyed || currentRequest !== requestNumber) return;
			loading = false;
			renderResults(reason instanceof Error ? reason.message : "Search failed");
		}
	}

	const handleInput = () => {
		if (debounceTimer) clearTimeout(debounceTimer);
		debounceTimer = setTimeout(() => runSearch(input.value), Math.max(0, options.debounceMs ?? 250));
	};
	const handleClear = () => {
		input.value = "";
		items = [];
		hasMore = false;
		requestNumber += 1;
		selectItem(null);
		input.focus();
	};
	input.addEventListener("input", handleInput);
	clearButton.addEventListener("click", handleClear);
	replaceContents(target, root);
	selectItem(selected, false);

	return {
		element: root,
		input,
		valueInput,
		getSelected: () => selected,
		getSelectedId: () => selected !== null ? options.getId(selected) : null,
		setSelected(item) {
			selectItem(item);
		},
		setQuery(query) {
			input.value = query;
		},
		search: (query) => runSearch(query ?? input.value),
		clear: handleClear,
		destroy() {
			destroyed = true;
			requestNumber += 1;
			if (debounceTimer) clearTimeout(debounceTimer);
			input.removeEventListener("input", handleInput);
			clearButton.removeEventListener("click", handleClear);
			root.remove();
		},
	};
}

function getCustomCrs() {
	const zoomNumber = 0.6931471805599453;
	return L.extend({}, CRS.Simple, {
		projection: Projection.LonLat,
		scale: (zoom: number) => Math.pow(2, zoom),
		zoom: (scale: number) => Math.log(scale) / zoomNumber,
		distance: (a: L.LatLng, b: L.LatLng) => Math.hypot(b.lng - a.lng, b.lat - a.lat),
		transformation: new Transformation(0.02072, 117.3, -0.0205, 172.8),
		infinite: false,
	});
}

function toMapLatLng(coords: { x: number; y: number }): [number, number] {
	return [coords.y / COORD_SCALE, coords.x / COORD_SCALE];
}

function createMap(target: HTMLElement, options: ModuleMapOptions): ModuleMapController {
	installStyles();
	const element = document.createElement("div");
	element.className = `ps-mdt-module-map${options.className ? ` ${options.className}` : ""}`;
	replaceContents(target, element);

	const map = L.map(element, {
		crs: getCustomCrs(),
		minZoom: options.minZoom ?? 3,
		maxZoom: options.maxZoom ?? 10,
		zoom: options.zoom ?? 4,
		preferCanvas: true,
		center: options.center ?? [-300, -1500],
		zoomControl: false,
		maxBoundsViscosity: 1,
	} as L.MapOptions);
	if (options.zoomControl !== false) L.control.zoom({ position: "topright" }).addTo(map);

	const southWest = map.unproject([0, 1024], 2);
	const northEast = map.unproject([1024, 0], 2);
	const bounds = L.latLngBounds(southWest, northEast);
	map.setView(options.center ?? [-300, -1500], options.zoom ?? 4);
	map.setMaxBounds(bounds);
	map.attributionControl.setPrefix(false);
	L.imageOverlay(new URL("./images/map.jpeg", window.location.href).href, bounds).addTo(map);
	map.on("dragend", () => {
		if (!bounds.contains(map.getCenter())) map.panTo(bounds.getCenter(), { animate: false });
	});

	return {
		element,
		map,
		toMapLatLng,
		setView(coords, zoom) {
			map.setView(toMapLatLng(coords), zoom ?? map.getZoom());
		},
		invalidateSize() {
			map.invalidateSize();
		},
		destroy() {
			map.remove();
			element.remove();
		},
	};
}

export function createModuleUi(resolveOptions: OptionResolver): ModuleUiApi {
	return {
		createSelect: (target, options = {}) => createSelect(target, options, resolveOptions),
		createList: (target, options = {}) => createList(target, options),
		createMap: (target, options = {}) => createMap(target, options),
		createSearchPicker: (target, options) => createSearchPicker(target, options),
	};
}
