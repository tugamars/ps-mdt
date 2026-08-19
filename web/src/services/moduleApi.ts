import type { AuthService } from "./authService.svelte";
import { fetchNui } from "../utils/fetchNui";
import { NUI_EVENTS } from "../constants/nuiEvents";
import { getReportTypesForJob, getTabsForJob } from "../constants";
import { globalNotifications } from "./notificationService.svelte";
import {
	createModuleUi,
	type ModuleOption,
	type ModuleSearchPickerController,
	type ModuleSearchPickerOptions,
	type ModuleSearchResponse,
	type ModuleUiApi,
} from "./moduleUi";
import type { ModuleTab } from "./moduleService.svelte";

export type ModuleOptionSource =
	| "core-tabs"
	| "module-tabs"
	| "current-module-tabs"
	| "all-tabs"
	| "job-types"
	| "report-types"
	| "permissions";

export interface ModuleApiContext {
	moduleTabs?: ModuleTab[];
}

export interface ModuleSearchOptions {
	page?: number;
	limit?: number;
}

export interface ModuleCitizenResult {
	id: string;
	citizenid: string;
	cid: string;
	profileId?: number;
	firstName: string;
	lastName: string;
	name: string;
	dateOfBirth?: string;
	dob?: string;
	phone?: string;
	occupation?: string;
	image?: string;
}

export interface ModuleReportResult {
	id: string | number;
	reportId: string | number;
	title: string;
	type: string;
	author?: string;
	datecreated?: string | number;
	dateupdated?: string | number;
	tag?: string;
}

export interface ModuleCaseResult {
	id: number;
	case_number: string;
	caseNumber: string;
	title: string;
	summary?: string;
	status: string;
	priority: string;
	assigned_department?: string;
	created_by?: string;
	created_by_name?: string;
	created_at?: string | number;
	updated_at?: string | number;
	primary_officer_name?: string;
	primary_officer_callsign?: string;
}

export interface ModuleSearchApi {
	citizens(query: string, options?: ModuleSearchOptions): Promise<ModuleSearchResponse<ModuleCitizenResult>>;
	civilians(query: string, options?: ModuleSearchOptions): Promise<ModuleSearchResponse<ModuleCitizenResult>>;
	reports(query: string, options?: ModuleSearchOptions): Promise<ModuleSearchResponse<ModuleReportResult>>;
	cases(query: string, options?: ModuleSearchOptions): Promise<ModuleSearchResponse<ModuleCaseResult>>;
}

export type ModuleDomainPickerOptions<T> = Omit<
	ModuleSearchPickerOptions<T>,
	"search" | "getId" | "getLabel" | "getDescription" | "getMeta"
>;

export interface ModuleApiUi extends ModuleUiApi {
	createCitizenSearch(target: HTMLElement, options?: ModuleDomainPickerOptions<ModuleCitizenResult>): ModuleSearchPickerController<ModuleCitizenResult>;
	createCivilianSearch(target: HTMLElement, options?: ModuleDomainPickerOptions<ModuleCitizenResult>): ModuleSearchPickerController<ModuleCitizenResult>;
	createReportSearch(target: HTMLElement, options?: ModuleDomainPickerOptions<ModuleReportResult>): ModuleSearchPickerController<ModuleReportResult>;
	createCaseSearch(target: HTMLElement, options?: ModuleDomainPickerOptions<ModuleCaseResult>): ModuleSearchPickerController<ModuleCaseResult>;
}

export interface ModuleApi {
	hasPermission(permission: string): boolean;
	fetchNui<T = unknown>(callback: string, data?: unknown): Promise<T>;
	notify(text: string, type?: "success" | "error" | "info"): void;
	getOptions(source: ModuleOptionSource): ModuleOption[];
	search: ModuleSearchApi;
	ui: ModuleApiUi;
}

export function createModuleApi(
	moduleId: string,
	authService: AuthService,
	context: ModuleApiContext = {},
): ModuleApi {
	function getOptions(source: ModuleOptionSource): ModuleOption[] {
		const jobType = authService.jobType === "ems" || authService.jobType === "doj"
			? authService.jobType
			: "leo";
		const moduleTabs = context.moduleTabs ?? [];
		const visibleModuleTabs = moduleTabs.filter((tab) => {
			if (tab.jobs?.length && !tab.jobs.includes(jobType)) return false;
			if (!tab.permissions?.length) return true;
			return authService.hasAnyPermission(...tab.permissions);
		});
		switch (source) {
			case "core-tabs":
				return getTabsForJob(jobType).map((tab) => ({ value: tab.name, label: tab.name }));
			case "module-tabs":
				return visibleModuleTabs.map((tab) => ({ value: tab.id, label: tab.name, group: tab.moduleName }));
			case "current-module-tabs":
				return visibleModuleTabs
					.filter((tab) => tab.moduleId === moduleId)
					.map((tab) => ({ value: tab.id, label: tab.name }));
			case "all-tabs":
				return [
					...getTabsForJob(jobType).map((tab) => ({ value: tab.name, label: tab.name, group: "Core" })),
					...visibleModuleTabs.map((tab) => ({ value: tab.id, label: tab.name, group: tab.moduleName ?? "Modules" })),
				];
			case "job-types":
				return [
					{ value: "leo", label: "Law Enforcement" },
					{ value: "ems", label: "Emergency Medical Services" },
					{ value: "doj", label: "Department of Justice" },
				];
			case "report-types":
				return getReportTypesForJob(jobType).map((label) => ({ value: label, label }));
			case "permissions":
				return authService.permissions.map((permission) => ({ value: permission, label: permission }));
			default:
				return [];
		}
	}

	async function searchCore<T>(
		domain: "citizens" | "reports" | "cases",
		query: string,
		options: ModuleSearchOptions = {},
	): Promise<ModuleSearchResponse<T>> {
		const response = await fetchNui<ModuleSearchResponse<T>>(NUI_EVENTS.MODULES.SEARCH_CORE, {
			domain,
			query,
			page: options.page ?? 1,
			limit: options.limit ?? 10,
		});
		return {
			items: Array.isArray(response?.items) ? response.items : [],
			page: response?.page ?? options.page ?? 1,
			hasMore: response?.hasMore === true,
			message: response?.message,
		};
	}

	const searchCitizens = (query: string, options?: ModuleSearchOptions) =>
		searchCore<ModuleCitizenResult>("citizens", query, options);
	const search: ModuleSearchApi = {
		citizens: searchCitizens,
		civilians: searchCitizens,
		reports: (query, options) => searchCore<ModuleReportResult>("reports", query, options),
		cases: (query, options) => searchCore<ModuleCaseResult>("cases", query, options),
	};
	const baseUi = createModuleUi((source) => getOptions(source as ModuleOptionSource));
	const ui: ModuleApiUi = Object.assign(baseUi, {
		createCitizenSearch(target: HTMLElement, options: ModuleDomainPickerOptions<ModuleCitizenResult> = {}) {
			return baseUi.createSearchPicker(target, {
				...options,
				search: (query, paging) => search.citizens(query, paging),
				getId: (item) => item.citizenid,
				getLabel: (item) => item.name || `${item.firstName ?? ""} ${item.lastName ?? ""}`.trim(),
				getDescription: (item) => [item.citizenid, item.dob].filter(Boolean).join(" · "),
				getMeta: (item) => item.occupation,
				placeholder: options.placeholder ?? "Search civilians...",
			});
		},
		createCivilianSearch(target: HTMLElement, options: ModuleDomainPickerOptions<ModuleCitizenResult> = {}) {
			return this.createCitizenSearch(target, options);
		},
		createReportSearch(target: HTMLElement, options: ModuleDomainPickerOptions<ModuleReportResult> = {}) {
			return baseUi.createSearchPicker(target, {
				...options,
				search: (query, paging) => search.reports(query, paging),
				getId: (item) => item.reportId,
				getLabel: (item) => item.title,
				getDescription: (item) => [`#${item.reportId}`, item.type].filter(Boolean).join(" · "),
				getMeta: (item) => item.author,
				placeholder: options.placeholder ?? "Search reports...",
			});
		},
		createCaseSearch(target: HTMLElement, options: ModuleDomainPickerOptions<ModuleCaseResult> = {}) {
			return baseUi.createSearchPicker(target, {
				...options,
				search: (query, paging) => search.cases(query, paging),
				getId: (item) => item.id,
				getLabel: (item) => item.title,
				getDescription: (item) => [item.caseNumber || item.case_number, item.status].filter(Boolean).join(" · "),
				getMeta: (item) => item.assigned_department,
				placeholder: options.placeholder ?? "Search cases...",
			});
		},
	});

	const api: ModuleApi = {
		hasPermission(permission: string) {
			return authService.hasPermission(permission);
		},
		fetchNui<T = unknown>(callback: string, data?: unknown) {
			return fetchNui<T>(NUI_EVENTS.MODULES.CALLBACK, {
				moduleId,
				callback,
				data: data ?? {},
			});
		},
		notify(text, type = "success") {
			globalNotifications.notify(text, type);
		},
		getOptions,
		search,
		ui,
	};
	return api;
}
