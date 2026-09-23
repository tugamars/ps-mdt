export interface Charge {
	code?: string;
	codeType?: string;
	codeTypeLabel?: string;
	label: string;
	description: string;
	expandedDefinition?: string;
	time: number;
	fine?: number;
	type: "felony" | "misdemeanor" | "infraction";
	category: string;
}

export interface GroupedCharges {
	felony: Record<string, Charge[]>;
	misdemeanor: Record<string, Charge[]>;
	infraction: Record<string, Charge[]>;
}
