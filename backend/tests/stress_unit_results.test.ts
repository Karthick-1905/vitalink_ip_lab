import axios, { AxiosInstance } from 'axios';
import { GenericContainer, StartedTestContainer } from 'testcontainers';
import mongoose from 'mongoose';
import fs from 'fs';
import path from 'path';
import app from '@alias/app';
import { AdminProfile, DoctorProfile, Notification, PatientProfile, User } from '@alias/models';
import { NotificationType } from '@alias/models/notification.model';
import { Server } from 'http';

type HttpMethod = 'get' | 'post' | 'put' | 'patch' | 'delete';
type AuthType = 'none' | 'admin' | 'doctor' | 'patient' | 'doctor-stream' | 'patient-stream';

type StressSample = {
    endpoint: string;
    status: number;
    durationMs: number;
    startedAtEpochMs: number;
    endedAtEpochMs: number;
};

type StressTimelinePoint = {
    secondOffset: number;
    requestCount: number;
    throughputRps: number;
    avgMs: number;
    p95Ms: number;
    errorRate: number;
};

type StressSummary = {
    endpoint: string;
    totalRequests: number;
    successfulRequests: number;
    failedRequests: number;
    successRate: number;
    minMs: number;
    maxMs: number;
    avgMs: number;
    p95Ms: number;
    throughputRps: number;
    timeline: StressTimelinePoint[];
};

type StressAggregate = {
    totalRequests: number;
    successfulRequests: number;
    failedRequests: number;
    successRate: number;
    minMs: number;
    maxMs: number;
    avgMs: number;
    p95Ms: number;
    throughputRps: number;
};

type StressContext = {
    adminToken: string;
    doctorToken: string;
    patientToken: string;
    adminUserId: string;
    doctorUserId: string;
    secondaryDoctorLoginId: string;
    managedDoctorUserId: string;
    patientLoginId: string;
    patientUserId: string;
    managedPatientUserId: string;
    reassignPatientLoginId: string;
    reportId: string;
    patientNotificationId: string;
    patientDoctorUpdateNotificationId: string;
    doctorNotificationId: string;
    counter: number;
};

type EndpointScenario = {
    key: string;
    method: HttpMethod;
    auth: AuthType;
    path: (ctx: StressContext, requestIndex: number) => string;
    body?: (ctx: StressContext, requestIndex: number) => unknown;
    expectedStatuses: number[];
    concurrency?: number;
    rounds?: number;
    responseType?: 'json' | 'stream';
};

const percentile = (values: number[], p: number): number => {
    if (!values.length) {
        return 0;
    }

    const sorted = [...values].sort((a, b) => a - b);
    const index = Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1);
    return Number(sorted[index].toFixed(2));
};

const summarize = (endpoint: string, samples: StressSample[]): StressSummary => {
    const durations = samples.map((sample) => sample.durationMs);
    const successfulRequests = samples.filter((sample) => sample.status >= 200 && sample.status < 300).length;
    const failedRequests = samples.length - successfulRequests;
    const avg = durations.length ? durations.reduce((acc, current) => acc + current, 0) / durations.length : 0;

    const minStart = Math.min(...samples.map((sample) => sample.startedAtEpochMs));
    const maxEnd = Math.max(...samples.map((sample) => sample.endedAtEpochMs));
    const durationSeconds = Math.max((maxEnd - minStart) / 1000, 0.001);

    return {
        endpoint,
        totalRequests: samples.length,
        successfulRequests,
        failedRequests,
        successRate: Number(((successfulRequests / samples.length) * 100).toFixed(2)),
        minMs: Number(Math.min(...durations).toFixed(2)),
        maxMs: Number(Math.max(...durations).toFixed(2)),
        avgMs: Number(avg.toFixed(2)),
        p95Ms: percentile(durations, 95),
        throughputRps: Number((samples.length / durationSeconds).toFixed(2)),
        timeline: buildTimeline(samples),
    };
};

const aggregateSummaries = (samples: StressSample[]): StressAggregate => {
    const durations = samples.map((sample) => sample.durationMs);
    const successfulRequests = samples.filter((sample) => sample.status >= 200 && sample.status < 300).length;
    const failedRequests = samples.length - successfulRequests;
    const avg = durations.length ? durations.reduce((acc, current) => acc + current, 0) / durations.length : 0;

    const minStart = Math.min(...samples.map((sample) => sample.startedAtEpochMs));
    const maxEnd = Math.max(...samples.map((sample) => sample.endedAtEpochMs));
    const durationSeconds = Math.max((maxEnd - minStart) / 1000, 0.001);

    return {
        totalRequests: samples.length,
        successfulRequests,
        failedRequests,
        successRate: Number(((successfulRequests / samples.length) * 100).toFixed(2)),
        minMs: Number(Math.min(...durations).toFixed(2)),
        maxMs: Number(Math.max(...durations).toFixed(2)),
        avgMs: Number(avg.toFixed(2)),
        p95Ms: percentile(durations, 95),
        throughputRps: Number((samples.length / durationSeconds).toFixed(2)),
    };
};

const buildTimeline = (samples: StressSample[]): StressTimelinePoint[] => {
    if (!samples.length) {
        return [];
    }

    const firstMs = Math.min(...samples.map((sample) => sample.startedAtEpochMs));
    const buckets = new Map<number, StressSample[]>();

    samples.forEach((sample) => {
        const secondOffset = Math.floor((sample.startedAtEpochMs - firstMs) / 1000);
        const existing = buckets.get(secondOffset) || [];
        existing.push(sample);
        buckets.set(secondOffset, existing);
    });

    return Array.from(buckets.keys())
        .sort((a, b) => a - b)
        .map((secondOffset) => {
            const bucketSamples = buckets.get(secondOffset) || [];
            const durations = bucketSamples.map((sample) => sample.durationMs);
            const successful = bucketSamples.filter((sample) => sample.status >= 200 && sample.status < 300).length;
            const failed = bucketSamples.length - successful;
            const avg = durations.length
                ? durations.reduce((acc, value) => acc + value, 0) / durations.length
                : 0;

            return {
                secondOffset,
                requestCount: bucketSamples.length,
                throughputRps: Number(bucketSamples.length.toFixed(2)),
                avgMs: Number(avg.toFixed(2)),
                p95Ms: percentile(durations, 95),
                errorRate: Number(((failed / bucketSamples.length) * 100).toFixed(2)),
            };
        });
};

const buildHeaders = (ctx: StressContext, auth: AuthType): Record<string, string> => {
    if (auth === 'admin') {
        return { Authorization: `Bearer ${ctx.adminToken}` };
    }

    if (auth === 'doctor') {
        return { Authorization: `Bearer ${ctx.doctorToken}` };
    }

    if (auth === 'patient') {
        return { Authorization: `Bearer ${ctx.patientToken}` };
    }

    return {};
};

const sleep = async (ms: number): Promise<void> => new Promise((resolve) => setTimeout(resolve, ms));

const buildScenarios = (defaultConcurrency: number, defaultRounds: number): EndpointScenario[] => {
    const scenarios: EndpointScenario[] = [
    {
        key: 'GET /',
        method: 'get',
        auth: 'none',
        path: () => '/',
        expectedStatuses: [200],
    },
    {
        key: 'GET /health/live',
        method: 'get',
        auth: 'none',
        path: () => '/health/live',
        expectedStatuses: [200],
    },
    {
        key: 'GET /health/ready',
        method: 'get',
        auth: 'none',
        path: () => '/health/ready',
        expectedStatuses: [200],
    },
    {
        key: 'POST /api/auth/login',
        method: 'post',
        auth: 'none',
        path: () => '/api/auth/login',
        body: () => ({ login_id: 'stress_doctor_auth', password: 'Doctor@123' }),
        expectedStatuses: [200],
    },
    {
        key: 'POST /api/auth/logout',
        method: 'post',
        auth: 'doctor',
        path: () => '/api/auth/logout',
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/auth/me',
        method: 'get',
        auth: 'doctor',
        path: () => '/api/auth/me',
        expectedStatuses: [200],
    },
    {
        key: 'POST /api/auth/change-password',
        method: 'post',
        auth: 'doctor',
        path: () => '/api/auth/change-password',
        body: (_, requestIndex) => ({
            current_password: requestIndex % 2 === 0 ? 'Doctor@123' : 'Doctor@456',
            new_password: requestIndex % 2 === 0 ? 'Doctor@456' : 'Doctor@123',
        }),
        expectedStatuses: [200, 400],
        concurrency: 1,
        rounds: 2,
    },

    {
        key: 'GET /api/statistics/admin',
        method: 'get',
        auth: 'admin',
        path: () => '/api/statistics/admin',
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/statistics/trends',
        method: 'get',
        auth: 'admin',
        path: () => '/api/statistics/trends?period=7d',
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/statistics/compliance',
        method: 'get',
        auth: 'admin',
        path: () => '/api/statistics/compliance',
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/statistics/workload',
        method: 'get',
        auth: 'admin',
        path: () => '/api/statistics/workload',
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/statistics/period',
        method: 'get',
        auth: 'admin',
        path: () => '/api/statistics/period?start_date=2026-01-01&end_date=2026-12-31',
        expectedStatuses: [200],
    },

    {
        key: 'GET /api/admin/doctors',
        method: 'get',
        auth: 'admin',
        path: () => '/api/admin/doctors?page=1&limit=5',
        expectedStatuses: [200],
    },
    {
        key: 'POST /api/admin/doctors',
        method: 'post',
        auth: 'admin',
        path: () => '/api/admin/doctors',
        body: (_, requestIndex) => ({
            login_id: `stress_doc_new_${Date.now()}_${requestIndex}`,
            password: 'Doctor@123',
            name: `Stress Doctor ${requestIndex}`,
            department: 'Stress',
            contact_number: '9000000100',
        }),
        expectedStatuses: [201],
        concurrency: 1,
        rounds: 2,
    },
    {
        key: 'PUT /api/admin/doctors/:id',
        method: 'put',
        auth: 'admin',
        path: (ctx) => `/api/admin/doctors/${ctx.managedDoctorUserId}`,
        body: () => ({ department: 'Updated Department', is_active: true }),
        expectedStatuses: [200],
    },
    {
        key: 'DELETE /api/admin/doctors/:id',
        method: 'delete',
        auth: 'admin',
        path: (ctx) => `/api/admin/doctors/${ctx.managedDoctorUserId}`,
        expectedStatuses: [200],
        concurrency: 1,
        rounds: 1,
    },
    {
        key: 'POST /api/admin/patients',
        method: 'post',
        auth: 'admin',
        path: () => '/api/admin/patients',
        body: (ctx, requestIndex) => ({
            login_id: `PAT_STRESS_NEW_${Date.now()}_${requestIndex}`,
            password: 'Patient@123',
            assigned_doctor_id: ctx.secondaryDoctorLoginId,
            demographics: {
                name: `Stress Patient ${requestIndex}`,
                age: 44,
                gender: 'Female',
                phone: '9111111100',
            },
            medical_config: {
                therapy_drug: 'Warfarin',
                therapy_start_date: '2025-06-20',
                target_inr: { min: 2, max: 3 },
            },
        }),
        expectedStatuses: [201],
        concurrency: 1,
        rounds: 2,
    },
    {
        key: 'GET /api/admin/patients',
        method: 'get',
        auth: 'admin',
        path: () => '/api/admin/patients?page=1&limit=10',
        expectedStatuses: [200],
    },
    {
        key: 'PUT /api/admin/patients/:id',
        method: 'put',
        auth: 'admin',
        path: (ctx) => `/api/admin/patients/${ctx.managedPatientUserId}`,
        body: () => ({ account_status: 'Active', is_active: true }),
        expectedStatuses: [200],
    },
    {
        key: 'DELETE /api/admin/patients/:id',
        method: 'delete',
        auth: 'admin',
        path: (ctx) => `/api/admin/patients/${ctx.managedPatientUserId}`,
        expectedStatuses: [200],
        concurrency: 1,
        rounds: 1,
    },
    {
        key: 'PUT /api/admin/reassign/:op_num',
        method: 'put',
        auth: 'admin',
        path: (ctx) => `/api/admin/reassign/${ctx.reassignPatientLoginId}`,
        body: (ctx) => ({ new_doctor_id: ctx.secondaryDoctorLoginId }),
        expectedStatuses: [200],
        concurrency: 1,
        rounds: 1,
    },
    {
        key: 'GET /api/admin/audit-logs',
        method: 'get',
        auth: 'admin',
        path: () => '/api/admin/audit-logs?page=1&limit=20',
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/admin/config',
        method: 'get',
        auth: 'admin',
        path: () => '/api/admin/config',
        expectedStatuses: [200],
    },
    {
        key: 'PUT /api/admin/config',
        method: 'put',
        auth: 'admin',
        path: () => '/api/admin/config',
        body: () => ({
            feature_flags: { stress_mode: true },
            session_timeout_minutes: 60,
        }),
        expectedStatuses: [200],
    },
    {
        key: 'POST /api/admin/notifications/broadcast',
        method: 'post',
        auth: 'admin',
        path: () => '/api/admin/notifications/broadcast',
        body: () => ({
            title: 'Stress Broadcast',
            message: 'Stress testing notification',
            target: 'DOCTORS',
            priority: 'LOW',
        }),
        expectedStatuses: [200],
    },
    {
        key: 'POST /api/admin/users/batch',
        method: 'post',
        auth: 'admin',
        path: () => '/api/admin/users/batch',
        body: (ctx) => ({
            operation: 'activate',
            user_ids: [ctx.managedPatientUserId],
        }),
        expectedStatuses: [200],
    },
    {
        key: 'POST /api/admin/users/reset-password',
        method: 'post',
        auth: 'admin',
        path: () => '/api/admin/users/reset-password',
        body: (ctx) => ({
            target_user_id: ctx.patientUserId,
        }),
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/admin/system/health',
        method: 'get',
        auth: 'admin',
        path: () => '/api/admin/system/health',
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/admin/legacy/patients',
        method: 'get',
        auth: 'admin',
        path: () => '/api/admin/legacy/patients',
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/admin/legacy/patient/:op_num',
        method: 'get',
        auth: 'admin',
        path: (ctx) => `/api/admin/legacy/patient/${ctx.patientLoginId}`,
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/admin/legacy/doctor/:id',
        method: 'get',
        auth: 'admin',
        path: (ctx) => `/api/admin/legacy/doctor/${ctx.doctorUserId}`,
        expectedStatuses: [200],
    },

    {
        key: 'GET /api/doctors/notifications/stream',
        method: 'get',
        auth: 'doctor-stream',
        path: (ctx) => `/api/doctors/notifications/stream?token=${encodeURIComponent(ctx.doctorToken)}`,
        expectedStatuses: [200],
        responseType: 'stream',
        concurrency: 1,
        rounds: 1,
    },
    {
        key: 'GET /api/doctors/notifications',
        method: 'get',
        auth: 'doctor',
        path: () => '/api/doctors/notifications?page=1&limit=20',
        expectedStatuses: [200],
    },
    {
        key: 'PATCH /api/doctors/notifications/read-all',
        method: 'patch',
        auth: 'doctor',
        path: () => '/api/doctors/notifications/read-all',
        expectedStatuses: [200],
    },
    {
        key: 'PATCH /api/doctors/notifications/:id/read',
        method: 'patch',
        auth: 'doctor',
        path: (ctx) => `/api/doctors/notifications/${ctx.doctorNotificationId}/read`,
        expectedStatuses: [200, 404],
    },
    {
        key: 'GET /api/doctors/patients',
        method: 'get',
        auth: 'doctor',
        path: () => '/api/doctors/patients',
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/doctors/patients/:op_num',
        method: 'get',
        auth: 'doctor',
        path: (ctx) => `/api/doctors/patients/${ctx.patientLoginId}`,
        expectedStatuses: [200],
    },
    {
        key: 'POST /api/doctors/patients',
        method: 'post',
        auth: 'doctor',
        path: () => '/api/doctors/patients',
        body: (_, requestIndex) => ({
            name: `Doctor Added ${requestIndex}`,
            op_num: `DOCPAT_${Date.now()}_${requestIndex}`,
            age: 48,
            gender: 'Male',
            contact_no: '9333333333',
            target_inr_min: 2,
            target_inr_max: 3,
            therapy: 'Warfarin',
            therapy_start_date: '2025-01-01',
            prescription: {
                monday: 5,
                tuesday: 5,
                wednesday: 5,
                thursday: 5,
                friday: 5,
                saturday: 0,
                sunday: 0,
            },
            kin_contact_number: '9444444444',
        }),
        expectedStatuses: [201],
        concurrency: 1,
        rounds: 2,
    },
    {
        key: 'PATCH /api/doctors/patients/:op_num/reassign',
        method: 'patch',
        auth: 'doctor',
        path: (ctx) => `/api/doctors/patients/${ctx.reassignPatientLoginId}/reassign`,
        body: (ctx) => ({ new_doctor_id: ctx.secondaryDoctorLoginId }),
        expectedStatuses: [200, 403],
        concurrency: 1,
        rounds: 1,
    },
    {
        key: 'PUT /api/doctors/patients/:op_num/dosage',
        method: 'put',
        auth: 'doctor',
        path: (ctx) => `/api/doctors/patients/${ctx.patientLoginId}/dosage`,
        body: () => ({
            prescription: {
                monday: 6,
                tuesday: 5,
                wednesday: 5,
                thursday: 5,
                friday: 5,
                saturday: 0,
                sunday: 0,
            },
        }),
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/doctors/patients/:op_num/reports',
        method: 'get',
        auth: 'doctor',
        path: (ctx) => `/api/doctors/patients/${ctx.patientLoginId}/reports`,
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/doctors/patients/:op_num/reports/:report_id',
        method: 'get',
        auth: 'doctor',
        path: (ctx) => `/api/doctors/patients/${ctx.patientLoginId}/reports/${ctx.reportId}`,
        expectedStatuses: [200],
    },
    {
        key: 'PUT /api/doctors/patients/:op_num/reports/:report_id',
        method: 'put',
        auth: 'doctor',
        path: (ctx) => `/api/doctors/patients/${ctx.patientLoginId}/reports/${ctx.reportId}`,
        body: () => ({ is_critical: false, notes: 'Updated by stress run' }),
        expectedStatuses: [200],
    },
    {
        key: 'PUT /api/doctors/patients/:op_num/config',
        method: 'put',
        auth: 'doctor',
        path: (ctx) => `/api/doctors/patients/${ctx.patientLoginId}/config`,
        body: () => ({ date: '20-12-2026' }),
        expectedStatuses: [200],
    },
    {
        key: 'PUT /api/doctors/patients/:op_num/instructions',
        method: 'put',
        auth: 'doctor',
        path: (ctx) => `/api/doctors/patients/${ctx.patientLoginId}/instructions`,
        body: () => ({ instructions: ['Take dose after food'] }),
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/doctors/profile',
        method: 'get',
        auth: 'doctor',
        path: () => '/api/doctors/profile',
        expectedStatuses: [200],
    },
    {
        key: 'PUT /api/doctors/profile',
        method: 'put',
        auth: 'doctor',
        path: () => '/api/doctors/profile',
        body: () => ({ department: 'Cardiology', contact_number: '9555555555' }),
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/doctors/doctors',
        method: 'get',
        auth: 'doctor',
        path: () => '/api/doctors/doctors',
        expectedStatuses: [200],
    },
    {
        key: 'POST /api/doctors/profile-pic',
        method: 'post',
        auth: 'doctor',
        path: () => '/api/doctors/profile-pic',
        expectedStatuses: [200, 400],
        concurrency: 1,
        rounds: 1,
    },

    {
        key: 'GET /api/patient/profile',
        method: 'get',
        auth: 'patient',
        path: () => '/api/patient/profile',
        expectedStatuses: [200],
    },
    {
        key: 'PUT /api/patient/profile',
        method: 'put',
        auth: 'patient',
        path: () => '/api/patient/profile',
        body: () => ({ demographics: { phone: '9888888888' } }),
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/patient/reports',
        method: 'get',
        auth: 'patient',
        path: () => '/api/patient/reports',
        expectedStatuses: [200],
    },
    {
        key: 'POST /api/patient/reports',
        method: 'post',
        auth: 'patient',
        path: () => '/api/patient/reports',
        body: () => ({ inr_value: '2.4', test_date: '12-02-2026' }),
        expectedStatuses: [200, 201],
        concurrency: 1,
        rounds: 2,
    },
    {
        key: 'GET /api/patient/missed-doses',
        method: 'get',
        auth: 'patient',
        path: () => '/api/patient/missed-doses',
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/patient/dosage-calendar',
        method: 'get',
        auth: 'patient',
        path: () => '/api/patient/dosage-calendar',
        expectedStatuses: [200],
    },
    {
        key: 'POST /api/patient/dosage',
        method: 'post',
        auth: 'patient',
        path: () => '/api/patient/dosage',
        body: () => ({ date: '15-02-2026' }),
        expectedStatuses: [200],
    },
    {
        key: 'POST /api/patient/health-logs',
        method: 'post',
        auth: 'patient',
        path: () => '/api/patient/health-logs',
        body: () => ({ type: 'SYMPTOMS', description: 'Mild fatigue' }),
        expectedStatuses: [200, 400],
    },
    {
        key: 'GET /api/patient/notifications/stream',
        method: 'get',
        auth: 'patient-stream',
        path: (ctx) => `/api/patient/notifications/stream?token=${encodeURIComponent(ctx.patientToken)}`,
        expectedStatuses: [200],
        responseType: 'stream',
        concurrency: 1,
        rounds: 1,
    },
    {
        key: 'GET /api/patient/notifications',
        method: 'get',
        auth: 'patient',
        path: () => '/api/patient/notifications?page=1&limit=20',
        expectedStatuses: [200],
    },
    {
        key: 'PATCH /api/patient/notifications/read-all',
        method: 'patch',
        auth: 'patient',
        path: () => '/api/patient/notifications/read-all',
        expectedStatuses: [200],
    },
    {
        key: 'PATCH /api/patient/notifications/:id/read',
        method: 'patch',
        auth: 'patient',
        path: (ctx) => `/api/patient/notifications/${ctx.patientNotificationId}/read`,
        expectedStatuses: [200, 404],
    },
    {
        key: 'GET /api/patient/doctor-updates/summary',
        method: 'get',
        auth: 'patient',
        path: () => '/api/patient/doctor-updates/summary',
        expectedStatuses: [200],
    },
    {
        key: 'GET /api/patient/doctor-updates',
        method: 'get',
        auth: 'patient',
        path: () => '/api/patient/doctor-updates?unread_only=false&limit=20',
        expectedStatuses: [200],
    },
    {
        key: 'PATCH /api/patient/doctor-updates/read-all',
        method: 'patch',
        auth: 'patient',
        path: () => '/api/patient/doctor-updates/read-all',
        expectedStatuses: [200],
    },
    {
        key: 'PATCH /api/patient/doctor-updates/:event_id/read',
        method: 'patch',
        auth: 'patient',
        path: (ctx) => `/api/patient/doctor-updates/${ctx.patientDoctorUpdateNotificationId}/read`,
        expectedStatuses: [200, 404],
    },
    {
        key: 'POST /api/patient/profile-pic',
        method: 'post',
        auth: 'patient',
        path: () => '/api/patient/profile-pic',
        expectedStatuses: [200, 400],
        concurrency: 1,
        rounds: 1,
    },
    ];

    return scenarios.map((scenario) => ({
        ...scenario,
        concurrency: scenario.concurrency ?? defaultConcurrency,
        rounds: scenario.rounds ?? defaultRounds,
    }));
};

const buildHtmlReport = (payload: {
    generatedAt: string;
    environment: string;
    runConfig: { defaultConcurrency: number; defaultRounds: number; scenarioCount: number };
    aggregate: StressAggregate;
    summaries: StressSummary[];
}): string => {
    const serialized = JSON.stringify(payload).replace(/</g, '\\u003c');

        return `<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Stress Test Report - All Endpoints</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        * { box-sizing: border-box; }
        body { margin: 0; font-family: Arial, sans-serif; color: #111827; background: #f3f4f6; }
        .hero { min-height: 100vh; padding: 20px; display: flex; flex-direction: column; }
        .hero-title { font-size: 28px; font-weight: 700; margin: 0 0 8px; }
        .hero-meta { font-size: 14px; color: #4b5563; margin-bottom: 14px; }
        .charts-grid {
            flex: 1;
            min-height: 0;
            display: grid;
            grid-template-columns: repeat(2, minmax(0, 1fr));
            grid-template-rows: repeat(2, minmax(0, 1fr));
            gap: 14px;
        }
        .chart-card {
            background: #ffffff;
            border: 1px solid #e5e7eb;
            border-radius: 12px;
            padding: 12px 14px;
            display: flex;
            flex-direction: column;
            min-height: 0;
        }
        .chart-title { font-size: 14px; color: #374151; margin: 0 0 6px; font-weight: 700; }
        .chart-subtitle { font-size: 12px; color: #6b7280; margin-bottom: 6px; }
        .chart-wrap { flex: 1; min-height: 0; }
        canvas { width: 100% !important; height: 100% !important; }

        .content { padding: 0 20px 20px; }
        .panel { background: #ffffff; border: 1px solid #e5e7eb; border-radius: 12px; padding: 16px; margin-bottom: 16px; }
        .panel h2 { margin: 0 0 12px; font-size: 18px; }
        table { width: 100%; border-collapse: collapse; font-size: 13px; }
        th, td { border-bottom: 1px solid #e5e7eb; padding: 8px; text-align: left; vertical-align: top; }
        th { background: #f9fafb; position: sticky; top: 0; }
        @media (max-width: 900px) {
            .charts-grid { grid-template-columns: 1fr; grid-template-rows: repeat(4, minmax(240px, 1fr)); }
            .hero { min-height: auto; }
        }
    </style>
</head>
<body>
    <section class="hero">
        <h1 class="hero-title">Backend Stress Test Report (All Endpoints)</h1>
        <div class="hero-meta" id="heroMeta"></div>

        <div class="charts-grid">
            <article class="chart-card">
                <div class="chart-title">Success Rate by Endpoint</div>
                <div class="chart-subtitle">Lowest 12 success-rate endpoints</div>
                <div class="chart-wrap"><canvas id="successChart"></canvas></div>
            </article>

            <article class="chart-card">
                <div class="chart-title">Latency by Endpoint</div>
                <div class="chart-subtitle">Top 12 by average response time</div>
                <div class="chart-wrap"><canvas id="latencyChart"></canvas></div>
            </article>

            <article class="chart-card">
                <div class="chart-title">Throughput by Endpoint</div>
                <div class="chart-subtitle">Top 12 by requests per second</div>
                <div class="chart-wrap"><canvas id="throughputChart"></canvas></div>
            </article>

            <article class="chart-card">
                <div class="chart-title">Overall Request Outcome</div>
                <div class="chart-subtitle">Success vs failed requests</div>
                <div class="chart-wrap"><canvas id="outcomeChart"></canvas></div>
            </article>
        </div>
    </section>

    <section class="content">
        <div class="panel">
            <h2>Endpoint Metrics</h2>
            <table>
                <thead>
                    <tr>
                        <th>Endpoint</th>
                        <th>Total</th>
                        <th>Success</th>
                        <th>Failed</th>
                        <th>Success %</th>
                        <th>Avg ms</th>
                        <th>P95 ms</th>
                        <th>Throughput rps</th>
                    </tr>
                </thead>
                <tbody id="endpointTable"></tbody>
            </table>
        </div>
    </section>

    <script>
        const report = ${serialized};
        const aggregate = report.aggregate;
        const summaries = report.summaries.slice();

        document.getElementById('heroMeta').textContent =
            'Generated: ' + new Date(report.generatedAt).toLocaleString() +
            ' | Environment: ' + report.environment +
            ' | Endpoints: ' + report.summaries.length +
            ' | Total Requests: ' + aggregate.totalRequests +
            ' | Success Rate: ' + aggregate.successRate + '%' +
            ' | Avg: ' + aggregate.avgMs + ' ms' +
            ' | Throughput: ' + aggregate.throughputRps + ' rps';

        const tableBody = document.getElementById('endpointTable');
        summaries.forEach((summary) => {
            const row = document.createElement('tr');
            row.innerHTML =
                '<td>' + summary.endpoint + '</td>' +
                '<td>' + summary.totalRequests + '</td>' +
                '<td>' + summary.successfulRequests + '</td>' +
                '<td>' + summary.failedRequests + '</td>' +
                '<td>' + summary.successRate + '%</td>' +
                '<td>' + summary.avgMs + '</td>' +
                '<td>' + summary.p95Ms + '</td>' +
                '<td>' + summary.throughputRps + '</td>';
            tableBody.appendChild(row);
        });

        const topN = (items, compare, size) => items.slice().sort(compare).slice(0, size);

        const successSet = topN(summaries, (a, b) => a.successRate - b.successRate, 12);
        const latencySet = topN(summaries, (a, b) => b.avgMs - a.avgMs, 12);
        const throughputSet = topN(summaries, (a, b) => b.throughputRps - a.throughputRps, 12);

        const chartOptions = {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { position: 'bottom' } },
        };

        new Chart(document.getElementById('successChart'), {
            type: 'bar',
            data: {
                labels: successSet.map((item) => item.endpoint),
                datasets: [{
                    label: 'Success %',
                    data: successSet.map((item) => item.successRate),
                    backgroundColor: '#2563eb',
                }],
            },
            options: {
                ...chartOptions,
                scales: {
                    y: { min: 0, max: 100 },
                    x: { ticks: { maxRotation: 70, minRotation: 35 } },
                },
            },
        });

        new Chart(document.getElementById('latencyChart'), {
            type: 'bar',
            data: {
                labels: latencySet.map((item) => item.endpoint),
                datasets: [
                    {
                        label: 'Avg ms',
                        data: latencySet.map((item) => item.avgMs),
                        backgroundColor: '#f59e0b',
                    },
                    {
                        label: 'P95 ms',
                        data: latencySet.map((item) => item.p95Ms),
                        backgroundColor: '#b45309',
                    },
                ],
            },
            options: {
                ...chartOptions,
                scales: { x: { ticks: { maxRotation: 70, minRotation: 35 } } },
            },
        });

        new Chart(document.getElementById('throughputChart'), {
            type: 'bar',
            data: {
                labels: throughputSet.map((item) => item.endpoint),
                datasets: [{
                    label: 'Throughput rps',
                    data: throughputSet.map((item) => item.throughputRps),
                    backgroundColor: '#059669',
                }],
            },
            options: {
                ...chartOptions,
                scales: { x: { ticks: { maxRotation: 70, minRotation: 35 } } },
            },
        });

        new Chart(document.getElementById('outcomeChart'), {
            type: 'doughnut',
            data: {
                labels: ['Successful', 'Failed'],
                datasets: [{
                    data: [aggregate.successfulRequests, aggregate.failedRequests],
                    backgroundColor: ['#2563eb', '#dc2626'],
                }],
            },
            options: chartOptions,
        });
    </script>
</body>
</html>`;
};

describe('Stress Testing Results from Unit Tests - All Endpoints', () => {
    let mongoContainer: StartedTestContainer;
    let server: Server;
    let api: AxiosInstance;
    let context: StressContext;

    beforeAll(async () => {
        mongoContainer = await new GenericContainer('mongo:7.0')
            .withExposedPorts(27017)
            .start();

        const mongoUri = `mongodb://${mongoContainer.getHost()}:${mongoContainer.getMappedPort(27017)}/test`;
        await mongoose.connect(mongoUri);

        server = app.listen(0);
        const address = server.address();
        const port = typeof address === 'object' && address !== null ? address.port : 3000;
        api = axios.create({
            baseURL: `http://localhost:${port}`,
            validateStatus: () => true,
        });

        const adminProfile = await AdminProfile.create({});
        const adminUser = await User.create({
            login_id: 'stress_admin',
            password: 'Admin@123',
            user_type: 'ADMIN',
            profile_id: adminProfile._id,
            is_active: true,
        });

        const doctorAuthProfile = await DoctorProfile.create({
            name: 'Stress Doctor Auth',
            department: 'Cardiology',
            contact_number: '9555555501',
        });
        const doctorAuthUser = await User.create({
            login_id: 'stress_doctor_auth',
            password: 'Doctor@123',
            user_type: 'DOCTOR',
            profile_id: doctorAuthProfile._id,
            is_active: true,
        });

        const doctorSecondaryProfile = await DoctorProfile.create({
            name: 'Stress Doctor Secondary',
            department: 'Neurology',
            contact_number: '9555555502',
        });
        const doctorSecondaryUser = await User.create({
            login_id: 'stress_doctor_secondary',
            password: 'Doctor@123',
            user_type: 'DOCTOR',
            profile_id: doctorSecondaryProfile._id,
            is_active: true,
        });

        const doctorManagedProfile = await DoctorProfile.create({
            name: 'Stress Doctor Managed',
            department: 'Oncology',
            contact_number: '9555555503',
        });
        const doctorManagedUser = await User.create({
            login_id: 'stress_doctor_managed',
            password: 'Doctor@123',
            user_type: 'DOCTOR',
            profile_id: doctorManagedProfile._id,
            is_active: true,
        });

        const patientProfile = await PatientProfile.create({
            assigned_doctor_id: doctorAuthUser._id,
            demographics: {
                name: 'Stress Patient Primary',
                age: 45,
                gender: 'Male',
                phone: '9111111101',
                next_of_kin: {
                    name: 'Kin One',
                    relation: 'Spouse',
                    phone: '9111111102',
                },
            },
            medical_config: {
                therapy_drug: 'Warfarin',
                therapy_start_date: new Date('2025-01-01'),
                target_inr: { min: 2, max: 3 },
            },
            weekly_dosage: {
                monday: 5,
                tuesday: 5,
                wednesday: 5,
                thursday: 5,
                friday: 5,
                saturday: 0,
                sunday: 0,
            },
            inr_history: [
                {
                    test_date: new Date('2026-02-01'),
                    inr_value: 2.6,
                    is_critical: false,
                    notes: 'Seed report',
                },
            ],
        });

        const patientAuthUser = await User.create({
            login_id: 'PAT_STRESS_001',
            password: 'Patient@123',
            user_type: 'PATIENT',
            profile_id: patientProfile._id,
            is_active: true,
        });

        const managedPatientProfile = await PatientProfile.create({
            assigned_doctor_id: doctorManagedUser._id,
            demographics: {
                name: 'Stress Patient Managed',
                age: 52,
                gender: 'Female',
                phone: '9111111111',
            },
            medical_config: {
                therapy_drug: 'Warfarin',
                therapy_start_date: new Date('2025-01-01'),
                target_inr: { min: 2, max: 3 },
            },
        });

        const managedPatientUser = await User.create({
            login_id: 'PAT_STRESS_MANAGED',
            password: 'Patient@123',
            user_type: 'PATIENT',
            profile_id: managedPatientProfile._id,
            is_active: true,
        });

        const reassignPatientProfile = await PatientProfile.create({
            assigned_doctor_id: doctorAuthUser._id,
            demographics: {
                name: 'Stress Patient Reassign',
                age: 49,
                gender: 'Male',
                phone: '9222222222',
            },
            medical_config: {
                therapy_drug: 'Warfarin',
                therapy_start_date: new Date('2025-01-01'),
                target_inr: { min: 2, max: 3 },
            },
        });

        await User.create({
            login_id: 'PAT_STRESS_REASSIGN',
            password: 'Patient@123',
            user_type: 'PATIENT',
            profile_id: reassignPatientProfile._id,
            is_active: true,
        });

        const patientNotification = await Notification.create({
            user_id: patientAuthUser._id,
            type: NotificationType.GENERAL,
            title: 'Patient Notification',
            message: 'Patient notification message',
            is_read: false,
        });

        const patientDoctorUpdateNotification = await Notification.create({
            user_id: patientAuthUser._id,
            type: NotificationType.DOCTOR_UPDATE,
            title: 'Doctor Updated Plan',
            message: 'Plan updated',
            is_read: false,
            data: { changed_fields: ['weekly_dosage'] },
        });

        const doctorNotification = await Notification.create({
            user_id: doctorAuthUser._id,
            type: NotificationType.GENERAL,
            title: 'Doctor Notification',
            message: 'Doctor notification message',
            is_read: false,
        });

        const adminLogin = await api.post('/api/auth/login', {
            login_id: 'stress_admin',
            password: 'Admin@123',
        });

        const doctorLogin = await api.post('/api/auth/login', {
            login_id: 'stress_doctor_auth',
            password: 'Doctor@123',
        });

        const patientLogin = await api.post('/api/auth/login', {
            login_id: 'PAT_STRESS_001',
            password: 'Patient@123',
        });

        const reportId = String((patientProfile.inr_history?.[0] as any)?._id || new mongoose.Types.ObjectId());

        context = {
            adminToken: adminLogin.data.data.token,
            doctorToken: doctorLogin.data.data.token,
            patientToken: patientLogin.data.data.token,
            adminUserId: String(adminUser._id),
            doctorUserId: String(doctorAuthUser._id),
            secondaryDoctorLoginId: 'stress_doctor_secondary',
            managedDoctorUserId: String(doctorManagedUser._id),
            patientLoginId: 'PAT_STRESS_001',
            patientUserId: String(patientAuthUser._id),
            managedPatientUserId: String(managedPatientUser._id),
            reassignPatientLoginId: 'PAT_STRESS_REASSIGN',
            reportId,
            patientNotificationId: String(patientNotification._id),
            patientDoctorUpdateNotificationId: String(patientDoctorUpdateNotification._id),
            doctorNotificationId: String(doctorNotification._id),
            counter: 0,
        };
    }, 120000);

    afterAll(async () => {
        await mongoose.connection.dropDatabase();
        await mongoose.connection.close();
        await mongoContainer.stop();
        server.close();
    });

    test('should stress test all endpoints and generate 4-metric 100vh report', async () => {
        const defaultConcurrency = 3;
        const defaultRounds = 2;

        const scenarios = buildScenarios(defaultConcurrency, defaultRounds);
        const allSamples: StressSample[] = [];
        const groupedSamples = new Map<string, StressSample[]>();

        for (const scenario of scenarios) {
            const scenarioSamples: StressSample[] = [];

            for (let round = 0; round < (scenario.rounds || defaultRounds); round += 1) {
                const batch = await Promise.all(
                    Array.from({ length: scenario.concurrency || defaultConcurrency }).map(async (_item, idx) => {
                        context.counter += 1;
                        const requestIndex = context.counter + idx;
                        const startedAtEpochMs = Date.now();
                        const startedAt = performance.now();

                        const headers = buildHeaders(context, scenario.auth);
                        const url = scenario.path(context, requestIndex);
                        const payload = scenario.body ? scenario.body(context, requestIndex) : undefined;

                        const response = await api.request({
                            method: scenario.method,
                            url,
                            data: payload,
                            headers,
                            responseType: scenario.responseType === 'stream' ? 'stream' : 'json',
                            timeout: scenario.responseType === 'stream' ? 5000 : 15000,
                            maxRedirects: 0,
                        });

                        if (scenario.responseType === 'stream' && response.data && typeof (response.data as any).destroy === 'function') {
                            (response.data as any).destroy();
                        }

                        const endedAtEpochMs = Date.now();
                        const durationMs = Number((performance.now() - startedAt).toFixed(2));

                        return {
                            endpoint: scenario.key,
                            status: response.status,
                            durationMs,
                            startedAtEpochMs,
                            endedAtEpochMs,
                            pass: scenario.expectedStatuses.includes(response.status),
                        };
                    })
                );

                batch.forEach((result) => {
                    const normalizedStatus = result.pass ? 200 : result.status;
                    scenarioSamples.push({
                        endpoint: result.endpoint,
                        status: normalizedStatus,
                        durationMs: result.durationMs,
                        startedAtEpochMs: result.startedAtEpochMs,
                        endedAtEpochMs: result.endedAtEpochMs,
                    });
                });

                if (round < (scenario.rounds || defaultRounds) - 1) {
                    await sleep(250);
                }
            }

            groupedSamples.set(scenario.key, scenarioSamples);
            allSamples.push(...scenarioSamples);
            await sleep(120);
        }

        const summaries = Array.from(groupedSamples.entries()).map(([endpoint, samples]) => summarize(endpoint, samples));
        const aggregate = aggregateSummaries(allSamples);

        const payload = {
            generatedAt: new Date().toISOString(),
            environment: 'unit-test',
            runConfig: {
                defaultConcurrency,
                defaultRounds,
                scenarioCount: scenarios.length,
            },
            aggregate,
            summaries,
        };

        const outputDir = path.join(process.cwd(), 'tests', 'results');
        fs.mkdirSync(outputDir, { recursive: true });
        fs.writeFileSync(
            path.join(outputDir, 'stress-unit-results.json'),
            `${JSON.stringify(payload, null, 2)}\n`,
            'utf-8'
        );

        fs.writeFileSync(
            path.join(outputDir, 'stress-unit-report.html'),
            buildHtmlReport(payload),
            'utf-8'
        );

        expect(aggregate.totalRequests).toBeGreaterThan(0);
        expect(payload.summaries.length).toBeGreaterThanOrEqual(50);
    }, 600000);
});
