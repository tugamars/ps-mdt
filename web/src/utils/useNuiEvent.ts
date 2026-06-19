import { onMount, onDestroy } from "svelte";
import type { NuiEventName } from "../constants/nuiEvents";
import {
	validateNuiMessage,
	validateNuiAction,
	nuiRateLimit,
} from "../security/nuiSecurity";

export function useNuiEvent<T = any>(
	action: NuiEventName,
	handler: (data: T) => void,
) {
	const eventListener = (event: MessageEvent) => {
		const { action: eventAction, data } = event.data;

		// Security: Validate the event action (silent)
		if (!validateNuiAction(eventAction)) {
			// Silent rejection - don't reveal validation details
			return;
		}

		// Security: Rate limiting (silent)
		if (!nuiRateLimit.isAllowed(eventAction)) {
			// Silent rejection - don't reveal rate limiting
			return;
		}

		// Security: Validate the event data (silent)
		const validation = validateNuiMessage(data);
		if (!validation.isValid) {
			// Silent rejection - don't reveal validation details
			return;
		}

		if (eventAction === action) {
			handler(validation.sanitized);
		}
	};

	try {
		// If this is called inside a Svelte component, onMount will work
		onMount(() => {
			window.addEventListener("message", eventListener);
		});

		onDestroy(() => {
			window.removeEventListener("message", eventListener);
		});
	} catch (e) {
		// If we're outside a Svelte component, onMount will throw an error.
		// We'll just add the event listener directly.
		// Note: This means the listener will not be automatically removed.
		window.addEventListener("message", eventListener);
	}
}
