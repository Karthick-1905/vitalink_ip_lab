import { z } from 'zod'

const ddmmyyyy = z.string('Date should be a string')
	.regex(/^\d{2}-\d{2}-\d{4}$/ , 'Date must be in DD-MM-YYYY format')
	.transform((val) => {
		const [day, month, year] = val.split('-').map(Number)
		return new Date(year, month - 1, day)
	})

export const logInrSchema = z.object({
	body: z.object({
		inr_value: z.number('INR value should be a number'),
		test_date: ddmmyyyy,
		notes: z.string().optional(),
		is_critical: z.boolean().optional(),
	})
})
export type LogInrInput = z.infer<typeof logInrSchema>

export const reportSchema = z.object({
	body: z.object({
		inr_value: z.number('INR value should be a number'),
		test_date: ddmmyyyy,
		notes: z.string().optional(),
		is_critical: z.boolean().optional(),
	})
})
export type ReportInput = z.infer<typeof reportSchema>

export const missedDoseSchema = z.object({
	body: z.object({}).strict()
})
export type MissedDoseInput = z.infer<typeof missedDoseSchema>

export const takeDosageSchema = z.object({
	body: z.object({
		date: ddmmyyyy,
	})
})
export type TakeDosageInput = z.infer<typeof takeDosageSchema>
