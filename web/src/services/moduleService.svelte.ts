import { useNuiEvent } from "@/utils/useNuiEvent";
import { NUI_EVENTS } from "@/constants/nuiEvents";
import { fetchNui } from "@/utils/fetchNui";

export interface ModuleTab {
    id: string;
    moduleId: string;
    moduleName?: string;
    name: string;
    icon: string;
    component: string;
    permissions?: string[];
    jobs?: Array<'leo' | 'ems' | 'doj'>;
    group?: string | {
        id: string;
        label?: string;
        icon?: string;
    };
}

let moduleTabs = $state<ModuleTab[]>([]);

async function fetchModuleTabs() {
    try {
        const tabs = await fetchNui<ModuleTab[]>(NUI_EVENTS.MODULES.GET_MODULE_TABS);
        if (Array.isArray(tabs)) {
            moduleTabs = tabs;
        }
    } catch (error) {
        console.error("Failed to fetch module tabs:", error);
    }
}

export function createModuleService() {
    fetchModuleTabs();

    useNuiEvent<ModuleTab[]>(NUI_EVENTS.MODULES.SET_MODULE_TABS, (tabs) => {
        moduleTabs = Array.isArray(tabs) ? tabs : [];
    });

    return {
        get moduleTabs() {
            return moduleTabs;
        },
        getTabByName(name: string) {
            return moduleTabs.find(tab => tab.name === name);
        }
    };
}

export const moduleService = createModuleService();
