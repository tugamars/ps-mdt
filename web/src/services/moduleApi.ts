import type { AuthService } from "./authService.svelte";
import { fetchNui } from "../utils/fetchNui";
import { NUI_EVENTS } from "../constants/nuiEvents";

export interface ModuleApi {
	hasPermission(permission: string): boolean;
	fetchNui<T = unknown>(callback: string, data?: unknown): Promise<T>;
}

export function createModuleApi(moduleId: string, authService: AuthService): ModuleApi {
	return {
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
	};
}
