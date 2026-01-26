import { Request, Response } from 'express'
import { ApiError, ApiResponse, asyncHandler } from '@src/utils'
import { StatusCodes } from 'http-status-codes'
import { PatientProfile, User } from '@src/models'
import { UserType } from '@src/validators'
import type { LogInrInput, MissedDoseInput, ReportInput, TakeDosageInput } from '@src/validators/patient.validator'

export const getProfile = asyncHandler(async (req: Request, res: Response) => {
    const {user_id} = req.user
	const user = await User.findById(user_id).populate('profile_id')
	if (!user || user.user_type !== UserType.PATIENT) {
		throw new ApiError(StatusCodes.NOT_FOUND, 'Patient not found')
	}
	res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Profile fetched successfully', { patient: user }))
})

export const updateinr = asyncHandler(async (req: Request<{}, {}, LogInrInput['body']>, res: Response) => {
	const patientUser = await User.findById(req.user.user_id)

	const { inr_value, test_date, notes, is_critical } = req.body

	const patient = await PatientProfile.findByIdAndUpdate(
		patientUser.profile_id,
		{
			$push: {
				inr_history: {
					test_date,
					uploaded_at: new Date(),
					inr_value,
					is_critical: is_critical ?? false,
					notes,
				},
			},
		},
		{ new: true }
	)

	res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'INR updated successfully', { patient }))
})

export const getReport = asyncHandler(async (req: Request, res: Response) => {
	if (!req.user) {
		throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized')
	}

	const patientUser = await User.findById(req.user.user_id)
	if (!patientUser || patientUser.user_type !== UserType.PATIENT) {
		throw new ApiError(StatusCodes.NOT_FOUND, 'Patient not found')
	}

	const patient = await PatientProfile.findById(patientUser.profile_id).select('inr_history health_logs weekly_dosage medical_config')
	res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Report fetched', { report: patient }))
})

export const submitReport = asyncHandler(async (req: Request<{}, {}, ReportInput['body']>, res: Response) => {
	if (!req.user) {
		throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized')
	}

	const patientUser = await User.findById(req.user.user_id)
	if (!patientUser || patientUser.user_type !== UserType.PATIENT) {
		throw new ApiError(StatusCodes.NOT_FOUND, 'Patient not found')
	}

	const { inr_value, test_date, notes, is_critical } = req.body
	const file = (req as any).file as Express.Multer.File | undefined

	if (file) {
		const allowed = ['application/pdf', 'image/png', 'image/jpeg']
		if (!allowed.includes(file.mimetype)) {
			throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid file type. Only PDF, PNG, JPEG allowed')
		}
	}

	const patient = await PatientProfile.findByIdAndUpdate(
		patientUser.profile_id,
		{
			$push: {
				inr_history: {
					test_date,
					uploaded_at: new Date(),
					inr_value,
					is_critical: is_critical ?? false,
					notes,
					file_url: file?.path,
				},
			},
		},
		{ new: true }
	)

	res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Report submitted', { patient }))
})

// TODO: Need to Review The Routes and Logic After This Later
export const missedDoses = asyncHandler(async (req: Request<{}, {}, MissedDoseInput['body']>, res: Response) => {
	const patientUser = await User.findById(req.user.user_id)

	const patient = await PatientProfile.findById(patientUser.profile_id)
	if (!patient) {
		throw new ApiError(StatusCodes.NOT_FOUND, 'Patient profile not found')
	}

	const therapyStart = patient.medical_config?.therapy_start_date
	const dosage = patient.weekly_dosage as Record<string, number> | undefined
	if (!therapyStart || !dosage) {
		throw new ApiError(StatusCodes.BAD_REQUEST, 'Therapy start date or dosage schedule is missing')
	}

	const medicationDates = getMedicationDates(therapyStart, dosage)
	const takenDates: (Date | string)[] = (patient.medical_config?.taken_doses || []).map((d: any) =>
		d instanceof Date ? d : new Date(d)
	)
	const missed = findMissedDoses(medicationDates, takenDates)

	const today = new Date()
	const sevenDaysAgo = new Date()
	sevenDaysAgo.setDate(today.getDate() - 7)

	const recent_missed_doses: string[] = []
	const remaining_missed: string[] = []
	missed.forEach((d) => {
		const [day, month, year] = d.split('-').map(Number)
		const dateObj = new Date(year, month - 1, day)
		if (dateObj >= sevenDaysAgo && dateObj <= today) {
			recent_missed_doses.push(d)
		} else {
			remaining_missed.push(d)
		}
	})

	res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Missed doses calculated', 
        { recent_missed_doses, missed_doses: remaining_missed }))
})

export const takeDosage = asyncHandler(async (req: Request<{}, {}, TakeDosageInput['body']>, res: Response) => {
	const patientUser = await User.findById(req.user.user_id)

	const { date } = req.body
	const parsedDate = date instanceof Date ? date : parseDDMMYYYY(date)

	const patient = await PatientProfile.findByIdAndUpdate(
		patientUser.profile_id,
		{
			$push: {
				'medical_config.taken_doses': parsedDate,
			},
		},
		{ new: true }
	)

	res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Dosage logged', { patient }))
})

function parseDDMMYYYY(date: string | Date): Date {
    const regex = /^\d{2}-\d{2}-\d{4}$/
    if (date instanceof Date) return date
    if (typeof date !== 'string' || !regex.test(date)) {
    	throw new ApiError(StatusCodes.BAD_REQUEST, 'Date must be in DD-MM-YYYY format')
    }
    const [day, month, year] = date.split('-').map(Number)
    return new Date(year, month - 1, day)
}

function formatDDMMYYYY(d: Date): string {
	const dd = `${d.getDate()}`.padStart(2, '0')
	const mm = `${d.getMonth() + 1}`.padStart(2, '0')
	const yyyy = d.getFullYear()
	return `${dd}-${mm}-${yyyy}`
}

function getMedicationDates(startDate: Date, weeklyDosage: Record<string, number>): string[] {
	const daysMap: Record<string, number> = {
		monday: 0,
		tuesday: 1,
		wednesday: 2,
		thursday: 3,
		friday: 4,
		saturday: 5,
		sunday: 6,
	}

	const targetDays = Object.entries(weeklyDosage)
		.filter(([, val]) => typeof val === 'number' && val > 0)
		.map(([day]) => daysMap[day])
		.filter((v) => v !== undefined)

	const start = startDate instanceof Date ? startDate : new Date(startDate)
	const today = new Date()
	const dates: string[] = []
	let current = new Date(start)

	while (current <= today) {
		if (targetDays.includes(current.getDay())) {
			dates.push(formatDDMMYYYY(current))
		}
		current.setDate(current.getDate() + 1)
	}

	return dates
}

function findMissedDoses(medicationDates: string[], takenDates: Array<Date | string | unknown>): string[] {
	const takenFormatted = new Set(
		(takenDates || []).map((d) => {
			const dt = d instanceof Date
				? d
				: typeof d === 'string' || typeof d === 'number'
					? new Date(d)
					: new Date(String(d))
			return formatDDMMYYYY(dt)
		})
	)

	const missed = medicationDates.filter((d) => !takenFormatted.has(d))
	missed.sort((a, b) => {
		const [ad, am, ay] = a.split('-').map(Number)
		const [bd, bm, by] = b.split('-').map(Number)
		return new Date(ay, am - 1, ad).getTime() - new Date(by, bm - 1, bd).getTime()
	})
	return missed
}


