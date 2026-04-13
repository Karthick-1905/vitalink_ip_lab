const fs = require('fs');
const path = require('path');

const outDir = __dirname;
const now = new Date().toISOString();

const collectionInfo = {
  name: 'VitaLink Backend API',
  description: [
    'Generated from the `/backend` Express + TypeScript codebase.',
    '',
    'Coverage goals:',
    '- Success path validation for every discovered endpoint',
    '- Validation and schema error scenarios',
    '- Authentication and authorization checks',
    '- Operational edge cases such as duplicate data, invalid IDs, empty result sets, and stream endpoints',
    '',
    'Tokens:',
    '- `admin_token` for `/api/admin/*` and `/api/statistics/*`',
    '- `doctor_token` for `/api/doctors/*`',
    '- `patient_token` for `/api/patient/*`',
    '- `auth_token` is a generic convenience variable updated by login requests',
    '',
    'Import the companion environment file before running the collection.',
  ].join('\n'),
};

const envValues = [
  ['base_url', 'http://localhost:3000'],
  ['auth_token', ''],
  ['admin_login_id', 'admin001'],
  ['admin_password', 'Admin@123'],
  ['admin_token', ''],
  ['doctor_login_id', 'doctor001'],
  ['doctor_password', 'Doctor@123'],
  ['doctor_token', ''],
  ['patient_login_id', 'patient001'],
  ['patient_password', 'Patient@123'],
  ['patient_token', ''],
  ['doctor_id', 'replace-with-doctor-user-id'],
  ['patient_id', 'replace-with-patient-user-id'],
  ['patient_op_num', 'PAT001'],
  ['secondary_doctor_login_id', 'doctor002'],
  ['notification_id', 'replace-with-notification-object-id'],
  ['doctor_update_event_id', 'replace-with-doctor-update-object-id'],
  ['report_id', 'replace-with-report-object-id'],
  ['start_date', '2026-01-01'],
  ['end_date', '2026-12-31'],
  ['request_id', ''],
];

function jsonBody(obj) {
  return {
    mode: 'raw',
    raw: JSON.stringify(obj, null, 2),
    options: { raw: { language: 'json' } },
  };
}

function formDataBody(entries) {
  return {
    mode: 'formdata',
    formdata: entries.map((entry) => ({
      key: entry.key,
      type: entry.type || 'text',
      src: entry.src,
      value: entry.value,
      description: entry.description,
    })),
  };
}

function authHeader(tokenVar) {
  return [{ key: 'Authorization', value: `Bearer {{${tokenVar}}}` }];
}

function withJsonHeaders(headers = []) {
  return [{ key: 'Content-Type', value: 'application/json' }, ...headers];
}

function makeUrl(pathTemplate, query = []) {
  const cleaned = pathTemplate.replace(/^\//, '');
  const rawBase = cleaned ? '{{base_url}}/' + cleaned : '{{base_url}}';
  return {
    raw: rawBase + (query.length ? '?' + query.map((q) => `${q.key}=${q.value}`).join('&') : ''),
    host: ['{{base_url}}'],
    path: cleaned ? cleaned.split('/') : [],
    query,
  };
}

function responseExample(name, statusCode, message, data) {
  return {
    name,
    originalRequest: {},
    status: statusCode >= 400 ? 'Error' : 'OK',
    code: statusCode,
    _postman_previewlanguage: 'json',
    header: [{ key: 'Content-Type', value: 'application/json' }],
    body: JSON.stringify(
      {
        statusCode,
        success: statusCode < 400,
        message,
        data: data === undefined ? null : data,
      },
      null,
      2
    ),
  };
}

function basicTestScript(expectedStatus, tokenVar, saveTokenTo, extraTests = []) {
  const script = [
    `pm.test("Status is ${expectedStatus}", function () {`,
    `  pm.response.to.have.status(${expectedStatus});`,
    `});`,
    `const contentType = pm.response.headers.get("Content-Type") || "";`,
    `if (contentType.includes("application/json")) {`,
    `  const json = pm.response.json();`,
    `  pm.test("Response has success flag", function () {`,
    `    pm.expect(json).to.have.property("success");`,
    `  });`,
    `  pm.test("Response message exists", function () {`,
    `    pm.expect(json).to.have.property("message");`,
    `  });`,
    `}`,
  ];

  if (tokenVar && saveTokenTo) {
    script.push(
      `if ((pm.response.headers.get("Content-Type") || "").includes("application/json")) {`,
      `  const json = pm.response.json();`,
      `  if (json?.data?.token) {`,
      `    pm.environment.set("${saveTokenTo}", json.data.token);`,
      `    pm.environment.set("auth_token", json.data.token);`,
      `  }`,
      `}`
    );
  }

  return script.concat(extraTests).join('\n');
}

function request({
  name,
  method,
  pathTemplate,
  description,
  tokenVar,
  headers = [],
  query = [],
  body,
  tests,
  responses = [],
}) {
  const item = {
    name,
    request: {
      method,
      header: headers,
      description,
      url: makeUrl(pathTemplate, query),
    },
    response: responses.map((response) => ({
      ...response,
      originalRequest: {
        method,
        header: headers,
        url: makeUrl(pathTemplate, query),
      },
    })),
    event: [],
  };

  if (body) {
    item.request.body = body;
  }

  if (tests) {
    item.event.push({
      listen: 'test',
      script: {
        type: 'text/javascript',
        exec: tests.split('\n'),
      },
    });
  }

  return item;
}

function scenarioLines(scenarios) {
  return scenarios.map((s) => `- ${s}`).join('\n');
}

function endpointDescription({ summary, auth, requestBody, queryParams, headers, scenarios }) {
  const lines = [summary, ''];
  if (auth) lines.push(`Auth: ${auth}`);
  if (headers) lines.push(`Headers: ${headers}`);
  if (queryParams) lines.push(`Query: ${queryParams}`);
  if (requestBody) lines.push(`Body: ${requestBody}`);
  if (scenarios && scenarios.length) {
    lines.push('', 'Test scenarios:', scenarioLines(scenarios));
  }
  return lines.join('\n');
}

const folders = [
  {
    name: 'Health',
    items: [
      request({
        name: 'API Root',
        method: 'GET',
        pathTemplate: '',
        description: endpointDescription({
          summary: 'Basic service reachability probe.',
          auth: 'None',
          scenarios: ['Success response from server root', 'Base URL misconfiguration'],
        }),
        tests: basicTestScript(200),
        responses: [
          responseExample('200 OK', 200, 'The Api is running', null),
        ],
      }),
      request({
        name: 'Live Health Check',
        method: 'GET',
        pathTemplate: 'health/live',
        description: endpointDescription({
          summary: 'Liveness endpoint that should stay green while the process is up.',
          auth: 'None',
          scenarios: ['Success response when process is alive'],
        }),
        tests: basicTestScript(200),
        responses: [
          responseExample('200 OK', 200, 'Service is live', null),
        ],
      }),
      request({
        name: 'Ready Health Check',
        method: 'GET',
        pathTemplate: 'health/ready',
        description: endpointDescription({
          summary: 'Readiness endpoint that reflects MongoDB connectivity.',
          auth: 'None',
          scenarios: ['200 when database is connected', '503 when database is disconnected'],
        }),
        tests: [
          'pm.test("Status is 200 or 503", function () {',
          '  pm.expect([200, 503]).to.include(pm.response.code);',
          '});',
          'const json = pm.response.json();',
          'pm.test("Readiness payload includes database state", function () {',
          '  pm.expect(json?.data?.database?.state).to.be.a("string");',
          '});',
        ].join('\n'),
        responses: [
          responseExample('200 Ready', 200, 'Service is ready', { database: { state: 'connected' } }),
          responseExample('503 Not Ready', 503, 'Service is not ready', { database: { state: 'disconnected' } }),
        ],
      }),
    ],
  },
  {
    name: 'Auth',
    items: [
      request({
        name: 'Login Admin',
        method: 'POST',
        pathTemplate: 'api/auth/login',
        headers: withJsonHeaders(),
        body: jsonBody({
          login_id: '{{admin_login_id}}',
          password: '{{admin_password}}',
        }),
        description: endpointDescription({
          summary: 'Admin login. Saves `admin_token` and updates generic `auth_token`.',
          auth: 'None',
          requestBody: '`login_id`, `password`',
          scenarios: ['Valid login returns JWT token', 'Unknown login ID returns 400', 'Wrong password returns 401', 'Inactive account returns 403', 'Missing fields return validation error'],
        }),
        tests: basicTestScript(200, true, 'admin_token', [
          'const json = pm.response.json();',
          'pm.test("Admin token is captured", function () {',
          '  pm.expect(json?.data?.token).to.be.a("string").and.not.empty;',
          '});',
        ]),
        responses: [
          responseExample('200 OK', 200, 'User logged in successfully', { token: 'jwt-token', user: { login_id: 'admin001', user_type: 'ADMIN' } }),
          responseExample('401 Unauthorized', 401, 'Invalid credentials', null),
        ],
      }),
      request({
        name: 'Login Doctor',
        method: 'POST',
        pathTemplate: 'api/auth/login',
        headers: withJsonHeaders(),
        body: jsonBody({
          login_id: '{{doctor_login_id}}',
          password: '{{doctor_password}}',
        }),
        description: endpointDescription({
          summary: 'Doctor login. Saves `doctor_token` and updates generic `auth_token`.',
          auth: 'None',
          requestBody: '`login_id`, `password`',
          scenarios: ['Valid doctor login', 'Credential failures', 'Inactive account'],
        }),
        tests: basicTestScript(200, true, 'doctor_token'),
      }),
      request({
        name: 'Login Patient',
        method: 'POST',
        pathTemplate: 'api/auth/login',
        headers: withJsonHeaders(),
        body: jsonBody({
          login_id: '{{patient_login_id}}',
          password: '{{patient_password}}',
        }),
        description: endpointDescription({
          summary: 'Patient login. Saves `patient_token` and updates generic `auth_token`.',
          auth: 'None',
          requestBody: '`login_id`, `password`',
          scenarios: ['Valid patient login', 'Credential failures', 'Inactive account'],
        }),
        tests: basicTestScript(200, true, 'patient_token'),
      }),
      request({
        name: 'Logout',
        method: 'POST',
        pathTemplate: 'api/auth/logout',
        headers: authHeader('auth_token'),
        description: endpointDescription({
          summary: 'Stateless logout acknowledgement.',
          auth: 'Bearer token',
          scenarios: ['Success with valid token', '401 without token', '401 with invalid token'],
        }),
        tests: basicTestScript(200),
        responses: [
          {
            name: '200 OK',
            originalRequest: {},
            status: 'OK',
            code: 200,
            _postman_previewlanguage: 'json',
            header: [{ key: 'Content-Type', value: 'application/json' }],
            body: JSON.stringify({ success: true, message: 'Logout successful. Please clear the token from client-side.' }, null, 2),
          },
        ],
      }),
      request({
        name: 'Get Current User',
        method: 'GET',
        pathTemplate: 'api/auth/me',
        headers: authHeader('auth_token'),
        description: endpointDescription({
          summary: 'Fetches the authenticated user and populated profile data.',
          auth: 'Bearer token',
          scenarios: ['Success with valid token', '401 without token', '401 with invalid token', '404 when JWT user no longer exists'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Change Password',
        method: 'POST',
        pathTemplate: 'api/auth/change-password',
        headers: withJsonHeaders(authHeader('auth_token')),
        body: jsonBody({
          current_password: '{{patient_password}}',
          new_password: 'NewStrong@123',
        }),
        description: endpointDescription({
          summary: 'Authenticated password rotation endpoint.',
          auth: 'Bearer token',
          requestBody: '`current_password`, `new_password`',
          scenarios: ['Success with strong new password', '401 when current password is wrong', '400 for weak password', '400 when new password matches current password', '401 without token'],
        }),
        tests: basicTestScript(200),
      }),
    ],
  },
  {
    name: 'Admin',
    items: [
      request({
        name: 'Create Doctor',
        method: 'POST',
        pathTemplate: 'api/admin/doctors',
        headers: withJsonHeaders(authHeader('admin_token')),
        body: jsonBody({
          login_id: 'doctor_admin_03',
          password: 'Doctor@456',
          name: 'Dr. Newly Added',
          department: 'Oncology',
          contact_number: '9000000003',
        }),
        description: endpointDescription({
          summary: 'Create a doctor account and profile.',
          auth: 'Admin bearer token',
          requestBody: '`login_id`, `password`, `name`, optional doctor profile fields',
          scenarios: ['201 for valid doctor creation', '409 for duplicate login ID', '400 for weak password or invalid URL fields', '401 without token', '403 for non-admin token'],
        }),
        tests: basicTestScript(201),
      }),
      request({
        name: 'List Doctors',
        method: 'GET',
        pathTemplate: 'api/admin/doctors',
        headers: authHeader('admin_token'),
        query: [
          { key: 'page', value: '1' },
          { key: 'limit', value: '10' },
          { key: 'department', value: 'Cardiology', disabled: true },
          { key: 'is_active', value: 'true', disabled: true },
          { key: 'search', value: 'john', disabled: true },
        ],
        description: endpointDescription({
          summary: 'Paginated doctor listing with filters.',
          auth: 'Admin bearer token',
          queryParams: '`page`, `limit`, `department`, `is_active`, `search`',
          scenarios: ['200 paginated success', '400 for invalid pagination inputs', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Update Doctor',
        method: 'PUT',
        pathTemplate: 'api/admin/doctors/{{doctor_id}}',
        headers: withJsonHeaders(authHeader('admin_token')),
        body: jsonBody({
          department: 'Nephrology',
          is_active: false,
        }),
        description: endpointDescription({
          summary: 'Update doctor profile or account state.',
          auth: 'Admin bearer token',
          requestBody: 'Optional profile and state fields',
          scenarios: ['200 success update', '404 when doctor is missing', '400 for invalid payload shape', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Deactivate Doctor',
        method: 'DELETE',
        pathTemplate: 'api/admin/doctors/{{doctor_id}}',
        headers: authHeader('admin_token'),
        description: endpointDescription({
          summary: 'Soft-deactivate a doctor account.',
          auth: 'Admin bearer token',
          scenarios: ['200 success deactivation', '404 when doctor is missing', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Create Patient',
        method: 'POST',
        pathTemplate: 'api/admin/patients',
        headers: withJsonHeaders(authHeader('admin_token')),
        body: jsonBody({
          login_id: 'PAT_ADMIN_NEW',
          password: 'Patient@456',
          assigned_doctor_id: '{{doctor_login_id}}',
          demographics: {
            name: 'Admin Onboarded Patient',
            age: 43,
            gender: 'Female',
            phone: '9222222222',
            next_of_kin: {
              name: 'Relative',
              relation: 'Sister',
              phone: '9333333333',
            },
          },
          medical_config: {
            therapy_drug: 'Warfarin',
            therapy_start_date: '2025-06-20',
            target_inr: { min: 2, max: 3 },
          },
        }),
        description: endpointDescription({
          summary: 'Create a patient and assign a doctor.',
          auth: 'Admin bearer token',
          requestBody: 'Patient account, demographics, doctor assignment, optional medical config',
          scenarios: ['201 success create', '400 when assigned doctor is invalid', '409 for duplicate login ID', '400 for invalid gender/INR schema', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(201),
      }),
      request({
        name: 'List Patients',
        method: 'GET',
        pathTemplate: 'api/admin/patients',
        headers: authHeader('admin_token'),
        query: [
          { key: 'page', value: '1' },
          { key: 'limit', value: '10' },
          { key: 'assigned_doctor_id', value: '{{doctor_id}}', disabled: true },
          { key: 'account_status', value: 'Active', disabled: true },
          { key: 'search', value: 'patient', disabled: true },
        ],
        description: endpointDescription({
          summary: 'Paginated patient listing with assignment and status filters.',
          auth: 'Admin bearer token',
          queryParams: '`page`, `limit`, `assigned_doctor_id`, `account_status`, `search`',
          scenarios: ['200 paginated success', '400 for invalid pagination input', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Update Patient',
        method: 'PUT',
        pathTemplate: 'api/admin/patients/{{patient_id}}',
        headers: withJsonHeaders(authHeader('admin_token')),
        body: jsonBody({
          account_status: 'Active',
          demographics: {
            phone: '9444444444',
          },
        }),
        description: endpointDescription({
          summary: 'Update patient account or profile fields.',
          auth: 'Admin bearer token',
          requestBody: 'Optional demographics, medical config, assignment, status, active flag, password',
          scenarios: ['200 success update', '404 when patient is missing', '400 for invalid status or schema', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Deactivate Patient',
        method: 'DELETE',
        pathTemplate: 'api/admin/patients/{{patient_id}}',
        headers: authHeader('admin_token'),
        description: endpointDescription({
          summary: 'Soft-deactivate a patient account.',
          auth: 'Admin bearer token',
          scenarios: ['200 success deactivation', '404 when patient is missing', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Reassign Patient',
        method: 'PUT',
        pathTemplate: 'api/admin/reassign/{{patient_op_num}}',
        headers: withJsonHeaders(authHeader('admin_token')),
        body: jsonBody({
          new_doctor_id: '{{secondary_doctor_login_id}}',
        }),
        description: endpointDescription({
          summary: 'Reassign patient ownership to a new doctor.',
          auth: 'Admin bearer token',
          requestBody: '`new_doctor_id`',
          scenarios: ['200 success reassignment', '404 when patient OP number is unknown', '400 when target doctor is invalid', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Get Audit Logs',
        method: 'GET',
        pathTemplate: 'api/admin/audit-logs',
        headers: authHeader('admin_token'),
        query: [
          { key: 'page', value: '1' },
          { key: 'limit', value: '20' },
          { key: 'user_id', value: '{{patient_id}}', disabled: true },
          { key: 'action', value: 'USER_CREATE', disabled: true },
          { key: 'start_date', value: '{{start_date}}', disabled: true },
          { key: 'end_date', value: '{{end_date}}', disabled: true },
          { key: 'success', value: 'true', disabled: true },
        ],
        description: endpointDescription({
          summary: 'Audit log search and pagination.',
          auth: 'Admin bearer token',
          queryParams: '`page`, `limit`, `user_id`, `action`, `start_date`, `end_date`, `success`',
          scenarios: ['200 paginated success', 'Invalid date filters handled by service', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Get System Config',
        method: 'GET',
        pathTemplate: 'api/admin/config',
        headers: authHeader('admin_token'),
        description: endpointDescription({
          summary: 'Fetch mutable system config document.',
          auth: 'Admin bearer token',
          scenarios: ['200 success', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Update System Config',
        method: 'PUT',
        pathTemplate: 'api/admin/config',
        headers: withJsonHeaders(authHeader('admin_token')),
        body: jsonBody({
          inr_thresholds: {
            critical_low: 1.5,
            critical_high: 4,
          },
          session_timeout_minutes: 60,
          rate_limit: {
            max_requests: 100,
            window_minutes: 15,
          },
          feature_flags: {
            doctor_updates: true,
          },
        }),
        description: endpointDescription({
          summary: 'Patch system config. Body is strict Zod schema.',
          auth: 'Admin bearer token',
          requestBody: '`inr_thresholds`, `session_timeout_minutes`, `rate_limit`, `feature_flags`',
          scenarios: ['200 success update', '400 for unexpected fields', '400 for non-positive numbers', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Broadcast Notification',
        method: 'POST',
        pathTemplate: 'api/admin/notifications/broadcast',
        headers: withJsonHeaders(authHeader('admin_token')),
        body: jsonBody({
          title: 'Maintenance',
          message: 'Scheduled maintenance tonight at 11 PM.',
          target: 'ALL',
          priority: 'HIGH',
        }),
        description: endpointDescription({
          summary: 'Broadcast notifications to users or segments.',
          auth: 'Admin bearer token',
          requestBody: '`title`, `message`, `target`, optional `user_ids`, `priority`',
          scenarios: ['200 success broadcast', '400 when target is SPECIFIC but user_ids missing', '400 for invalid target or priority', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Batch User Operation',
        method: 'POST',
        pathTemplate: 'api/admin/users/batch',
        headers: withJsonHeaders(authHeader('admin_token')),
        body: jsonBody({
          operation: 'deactivate',
          user_ids: ['{{patient_id}}'],
        }),
        description: endpointDescription({
          summary: 'Bulk activate, deactivate, or reset password.',
          auth: 'Admin bearer token',
          requestBody: '`operation`, `user_ids[]`',
          scenarios: ['200 success for valid operation', '400 for empty user_ids', '400 for unsupported operation', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Reset User Password',
        method: 'POST',
        pathTemplate: 'api/admin/users/reset-password',
        headers: withJsonHeaders(authHeader('admin_token')),
        body: jsonBody({
          target_user_id: '{{patient_id}}',
        }),
        description: endpointDescription({
          summary: 'Admin password reset with optional explicit replacement password.',
          auth: 'Admin bearer token',
          requestBody: '`target_user_id`, optional `new_password`',
          scenarios: ['200 success reset', '404 for unknown user', '400 for invalid body', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'System Health',
        method: 'GET',
        pathTemplate: 'api/admin/system/health',
        headers: authHeader('admin_token'),
        description: endpointDescription({
          summary: 'Administrative system health snapshot.',
          auth: 'Admin bearer token',
          scenarios: ['200 success with health metrics', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Legacy List Patients',
        method: 'GET',
        pathTemplate: 'api/admin/legacy/patients',
        headers: authHeader('admin_token'),
        description: endpointDescription({
          summary: 'Legacy patient listing endpoint.',
          auth: 'Admin bearer token',
          scenarios: ['200 success', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Legacy Get Patient By OP',
        method: 'GET',
        pathTemplate: 'api/admin/legacy/patient/{{patient_op_num}}',
        headers: authHeader('admin_token'),
        description: endpointDescription({
          summary: 'Legacy patient lookup by OP/login ID.',
          auth: 'Admin bearer token',
          scenarios: ['200 when patient exists', '404 when patient is missing', '401 without token', '403 for non-admin'],
        }),
        tests: [
          'pm.test("Status is 200 or 404", function () {',
          '  pm.expect([200, 404]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
      request({
        name: 'Legacy Get Doctor By ID',
        method: 'GET',
        pathTemplate: 'api/admin/legacy/doctor/{{doctor_id}}',
        headers: authHeader('admin_token'),
        description: endpointDescription({
          summary: 'Legacy doctor lookup by Mongo user ID.',
          auth: 'Admin bearer token',
          scenarios: ['200 when doctor exists', '404 when doctor is missing', '401 without token', '403 for non-admin'],
        }),
        tests: [
          'pm.test("Status is 200 or 404", function () {',
          '  pm.expect([200, 404]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
    ],
  },
  {
    name: 'Doctors',
    items: [
      request({
        name: 'Stream Notifications',
        method: 'GET',
        pathTemplate: 'api/doctors/notifications/stream',
        headers: [{ key: 'Accept', value: 'text/event-stream' }],
        query: [{ key: 'token', value: '{{doctor_token}}' }],
        description: endpointDescription({
          summary: 'Server-sent events stream for doctor notifications. Uses token query param or Authorization header.',
          auth: 'Doctor token via `token` query param or Authorization header',
          queryParams: '`token`',
          scenarios: ['Stream connects with valid token', '401 without token', '401 with invalid or expired token'],
        }),
      }),
      request({
        name: 'List Notifications',
        method: 'GET',
        pathTemplate: 'api/doctors/notifications',
        headers: authHeader('doctor_token'),
        query: [
          { key: 'page', value: '1' },
          { key: 'limit', value: '20' },
          { key: 'is_read', value: 'false', disabled: true },
        ],
        description: endpointDescription({
          summary: 'Paginated doctor notifications.',
          auth: 'Doctor bearer token',
          queryParams: '`page`, `limit`, `is_read`',
          scenarios: ['200 success', '400 for invalid ObjectId filters not applicable here', '400 for invalid pagination strings', '401 without token', '400 when non-doctor token is used'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Mark All Notifications Read',
        method: 'PATCH',
        pathTemplate: 'api/doctors/notifications/read-all',
        headers: authHeader('doctor_token'),
        description: endpointDescription({
          summary: 'Marks all doctor notifications as read.',
          auth: 'Doctor bearer token',
          scenarios: ['200 success', '401 without token', '400 when non-doctor token is used'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Mark Notification Read',
        method: 'PATCH',
        pathTemplate: 'api/doctors/notifications/{{notification_id}}/read',
        headers: authHeader('doctor_token'),
        description: endpointDescription({
          summary: 'Marks one doctor notification as read.',
          auth: 'Doctor bearer token',
          scenarios: ['200 when notification exists', '404 for unknown notification', '400 for invalid ObjectId', '401 without token', '400 when non-doctor token is used'],
        }),
        tests: [
          'pm.test("Status is 200 or 404", function () {',
          '  pm.expect([200, 404]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
      request({
        name: 'List Assigned Patients',
        method: 'GET',
        pathTemplate: 'api/doctors/patients',
        headers: authHeader('doctor_token'),
        description: endpointDescription({
          summary: 'Lists patients assigned to the authenticated doctor.',
          auth: 'Doctor bearer token',
          scenarios: ['200 with patients', '200 with empty array', '401 without token', '400 when non-doctor token is used'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Get Patient',
        method: 'GET',
        pathTemplate: 'api/doctors/patients/{{patient_op_num}}',
        headers: authHeader('doctor_token'),
        description: endpointDescription({
          summary: 'Fetch one patient by OP/login ID.',
          auth: 'Doctor bearer token',
          scenarios: ['200 when patient exists and belongs to doctor', '404 when patient is missing', '403 for unauthorized doctor-patient access', '401 without token'],
        }),
        tests: [
          'pm.test("Status is 200, 403, or 404", function () {',
          '  pm.expect([200, 403, 404]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
      request({
        name: 'Create Patient',
        method: 'POST',
        pathTemplate: 'api/doctors/patients',
        headers: withJsonHeaders(authHeader('doctor_token')),
        body: jsonBody({
          name: 'New Patient',
          op_num: 'PAT002',
          age: 50,
          gender: 'Female',
          contact_no: '8888888888',
          target_inr_min: 2.5,
          target_inr_max: 3.5,
          therapy: 'Warfarin',
          therapy_start_date: '2024-01-15',
          prescription: {
            monday: 4,
            tuesday: 4,
            wednesday: 4,
            thursday: 4,
            friday: 4,
            saturday: 4,
            sunday: 4,
          },
          medical_history: [
            {
              diagnosis: 'Atrial Fibrillation',
              duration_value: 2,
              duration_unit: 'Years',
            },
          ],
          kin_name: 'Family Contact',
          kin_relation: 'Sibling',
          kin_contact_number: '7777777777',
        }),
        description: endpointDescription({
          summary: 'Doctor-side patient creation with default temporary password equal to contact number.',
          auth: 'Doctor bearer token',
          requestBody: 'Patient demographics, OP number, dosage schedule, optional history and therapy config',
          scenarios: ['201 success create', '409 for duplicate OP number', '400 for invalid gender/date/contact lengths', '401 without token', '400 when non-doctor token is used'],
        }),
        tests: basicTestScript(201),
      }),
      request({
        name: 'Reassign Patient',
        method: 'PATCH',
        pathTemplate: 'api/doctors/patients/{{patient_op_num}}/reassign',
        headers: withJsonHeaders(authHeader('doctor_token')),
        body: jsonBody({
          new_doctor_id: '{{secondary_doctor_login_id}}',
        }),
        description: endpointDescription({
          summary: 'Doctor-triggered reassignment to another doctor login ID.',
          auth: 'Doctor bearer token',
          requestBody: '`new_doctor_id`',
          scenarios: ['200 success', '400 when target doctor is missing', '403 when patient is not owned by doctor', '404 for unknown patient', '401 without token'],
        }),
        tests: [
          'pm.test("Status is 200, 400, 403, or 404", function () {',
          '  pm.expect([200, 400, 403, 404]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
      request({
        name: 'Update Patient Dosage',
        method: 'PUT',
        pathTemplate: 'api/doctors/patients/{{patient_op_num}}/dosage',
        headers: withJsonHeaders(authHeader('doctor_token')),
        body: jsonBody({
          prescription: {
            monday: 5,
            tuesday: 5,
            wednesday: 5,
            thursday: 5,
            friday: 5,
            saturday: 0,
            sunday: 0,
          },
        }),
        description: endpointDescription({
          summary: 'Replace weekly dosage schedule.',
          auth: 'Doctor bearer token',
          requestBody: '`prescription` daily number map',
          scenarios: ['200 success', '400 for malformed schedule', '403 when patient ownership is wrong', '404 when patient is missing', '401 without token'],
        }),
        tests: [
          'pm.test("Status is 200, 403, or 404", function () {',
          '  pm.expect([200, 403, 404]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
      request({
        name: 'List Patient Reports',
        method: 'GET',
        pathTemplate: 'api/doctors/patients/{{patient_op_num}}/reports',
        headers: authHeader('doctor_token'),
        description: endpointDescription({
          summary: 'List patient INR reports with presigned file URLs when present.',
          auth: 'Doctor bearer token',
          scenarios: ['200 success', '403 when doctor does not own patient', '404 when patient is missing', '401 without token'],
        }),
        tests: [
          'pm.test("Status is 200, 403, or 404", function () {',
          '  pm.expect([200, 403, 404]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
      request({
        name: 'Get Patient Report',
        method: 'GET',
        pathTemplate: 'api/doctors/patients/{{patient_op_num}}/reports/{{report_id}}',
        headers: authHeader('doctor_token'),
        description: endpointDescription({
          summary: 'Fetch one patient report by embedded report ObjectId.',
          auth: 'Doctor bearer token',
          scenarios: ['200 success', '400 for invalid report_id', '403 when doctor does not own patient', '404 when report or patient is missing', '401 without token'],
        }),
        tests: [
          'pm.test("Status is 200, 400, 403, or 404", function () {',
          '  pm.expect([200, 400, 403, 404]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
      request({
        name: 'Update Patient Report',
        method: 'PUT',
        pathTemplate: 'api/doctors/patients/{{patient_op_num}}/reports/{{report_id}}',
        headers: withJsonHeaders(authHeader('doctor_token')),
        body: jsonBody({
          is_critical: true,
          notes: 'Please repeat INR test in 48 hours.',
        }),
        description: endpointDescription({
          summary: 'Update report notes or critical flag.',
          auth: 'Doctor bearer token',
          requestBody: 'Optional `is_critical`, `notes`',
          scenarios: ['200 success', '400 for invalid payload or report_id', '403 unauthorized patient access', '404 report missing', '401 without token'],
        }),
        tests: [
          'pm.test("Status is 200, 400, 403, or 404", function () {',
          '  pm.expect([200, 400, 403, 404]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
      request({
        name: 'Update Next Review',
        method: 'PUT',
        pathTemplate: 'api/doctors/patients/{{patient_op_num}}/config',
        headers: withJsonHeaders(authHeader('doctor_token')),
        body: jsonBody({
          date: '25-12-2026',
        }),
        description: endpointDescription({
          summary: 'Set next review date for the patient.',
          auth: 'Doctor bearer token',
          requestBody: '`date` in DD-MM-YYYY format',
          scenarios: ['200 success', '400 for invalid date format', '403 unauthorized patient access', '404 patient missing', '401 without token'],
        }),
        tests: [
          'pm.test("Status is 200, 400, 403, or 404", function () {',
          '  pm.expect([200, 400, 403, 404]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
      request({
        name: 'Update Instructions',
        method: 'PUT',
        pathTemplate: 'api/doctors/patients/{{patient_op_num}}/instructions',
        headers: withJsonHeaders(authHeader('doctor_token')),
        body: jsonBody({
          instructions: ['Take medicine after breakfast', 'Return for review next week'],
        }),
        description: endpointDescription({
          summary: 'Set patient care instructions.',
          auth: 'Doctor bearer token',
          requestBody: '`instructions[]`',
          scenarios: ['200 success', '400 when instructions is not an array of strings', '403 unauthorized patient access', '404 patient missing', '401 without token'],
        }),
        tests: [
          'pm.test("Status is 200, 400, 403, or 404", function () {',
          '  pm.expect([200, 400, 403, 404]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
      request({
        name: 'Get Profile',
        method: 'GET',
        pathTemplate: 'api/doctors/profile',
        headers: authHeader('doctor_token'),
        description: endpointDescription({
          summary: 'Fetch doctor profile with optional presigned profile image URL and patient count.',
          auth: 'Doctor bearer token',
          scenarios: ['200 success', '404 when doctor record is missing', '401 without token', '400 when non-doctor token is used'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Update Profile',
        method: 'PUT',
        pathTemplate: 'api/doctors/profile',
        headers: withJsonHeaders(authHeader('doctor_token')),
        body: jsonBody({
          name: 'Dr. Updated Name',
          department: 'Cardiology',
          contact_number: '1234567890',
        }),
        description: endpointDescription({
          summary: 'Update doctor profile fields.',
          auth: 'Doctor bearer token',
          requestBody: 'Optional `name`, `department`, `contact_number`',
          scenarios: ['200 success', '400 for invalid contact number length or extra fields', '404 when doctor record is missing', '401 without token'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'List Doctors',
        method: 'GET',
        pathTemplate: 'api/doctors/doctors',
        headers: authHeader('doctor_token'),
        description: endpointDescription({
          summary: 'List all doctor users with populated profiles.',
          auth: 'Doctor bearer token',
          scenarios: ['200 success', '401 without token', '400 when non-doctor token is used'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Upload Profile Picture',
        method: 'POST',
        pathTemplate: 'api/doctors/profile-pic',
        headers: authHeader('doctor_token'),
        body: formDataBody([
          {
            key: 'file',
            type: 'file',
            src: '/absolute/path/to/doctor-profile.jpg',
            description: 'PNG, JPEG, JPG, or WEBP. Max 5 MB.',
          },
        ]),
        description: endpointDescription({
          summary: 'Upload doctor profile image.',
          auth: 'Doctor bearer token',
          headers: 'Multipart form-data',
          requestBody: '`file`',
          scenarios: ['200 success', '400 when file is missing', '400 when file type is invalid', '400 when file exceeds 5 MB', '401 without token'],
        }),
      }),
    ],
  },
  {
    name: 'Patient',
    items: [
      request({
        name: 'Stream Notifications',
        method: 'GET',
        pathTemplate: 'api/patient/notifications/stream',
        headers: [{ key: 'Accept', value: 'text/event-stream' }],
        query: [{ key: 'token', value: '{{patient_token}}' }],
        description: endpointDescription({
          summary: 'Server-sent events stream for patient notifications.',
          auth: 'Patient token via `token` query param or Authorization header',
          queryParams: '`token`',
          scenarios: ['Stream connects with valid token', '401 without token', '401 with invalid or expired token'],
        }),
      }),
      request({
        name: 'Get Profile',
        method: 'GET',
        pathTemplate: 'api/patient/profile',
        headers: authHeader('patient_token'),
        description: endpointDescription({
          summary: 'Fetch patient profile with assigned doctor details and doctor update summary.',
          auth: 'Patient bearer token',
          scenarios: ['200 success', '401 without token', '404 if patient no longer exists', '400 when non-patient token is used'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Update Profile',
        method: 'PUT',
        pathTemplate: 'api/patient/profile',
        headers: withJsonHeaders(authHeader('patient_token')),
        body: jsonBody({
          demographics: {
            phone: '9876543210',
            next_of_kin: {
              relation: 'Spouse',
            },
          },
          medical_history: [
            {
              diagnosis: 'Atrial Fibrillation',
              duration_value: 2,
              duration_unit: 'Years',
            },
          ],
          medical_config: {
            therapy_start_date: '2024-01-01',
          },
        }),
        description: endpointDescription({
          summary: 'Update patient profile, history, and therapy start date.',
          auth: 'Patient bearer token',
          requestBody: 'Optional demographics, medical history, medical_config.therapy_start_date',
          scenarios: ['200 success', '400 for invalid gender or future therapy start date', '400 for unexpected fields due to strict schema', '401 without token'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Get Reports',
        method: 'GET',
        pathTemplate: 'api/patient/reports',
        headers: authHeader('patient_token'),
        description: endpointDescription({
          summary: 'Fetch INR history, health logs, weekly dosage, and medical config.',
          auth: 'Patient bearer token',
          scenarios: ['200 success', '401 without token', '404 when patient profile is missing'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Submit Report',
        method: 'POST',
        pathTemplate: 'api/patient/reports',
        headers: authHeader('patient_token'),
        body: formDataBody([
          { key: 'inr_value', value: '2.8' },
          { key: 'test_date', value: '20-02-2026' },
          {
            key: 'file',
            type: 'file',
            src: '/absolute/path/to/patient-report.pdf',
            description: 'Optional PDF, PNG, JPEG, or JPG. Max 10 MB.',
          },
        ]),
        description: endpointDescription({
          summary: 'Submit INR test result with optional upload.',
          auth: 'Patient bearer token',
          headers: 'Multipart form-data',
          requestBody: '`inr_value`, `test_date`, optional `file`',
          scenarios: ['200 success', '400 for non-numeric INR', '400 for invalid date format', '400 for invalid file type', '400 for file > 10 MB', '507/insufficient storage when upload backend fails', '401 without token'],
        }),
      }),
      request({
        name: 'Get Missed Doses',
        method: 'GET',
        pathTemplate: 'api/patient/missed-doses',
        headers: authHeader('patient_token'),
        description: endpointDescription({
          summary: 'Calculate missed doses from therapy start date, dosage schedule, and taken dose history.',
          auth: 'Patient bearer token',
          scenarios: ['200 success', '400 when therapy start or schedule is missing', '401 without token'],
        }),
        tests: [
          'pm.test("Status is 200 or 400", function () {',
          '  pm.expect([200, 400]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
      request({
        name: 'Get Dosage Calendar',
        method: 'GET',
        pathTemplate: 'api/patient/dosage-calendar',
        headers: authHeader('patient_token'),
        query: [
          { key: 'months', value: '3' },
          { key: 'start_date', value: '01-03-2026', disabled: true },
        ],
        description: endpointDescription({
          summary: 'Dose calendar with taken, missed, and scheduled dates.',
          auth: 'Patient bearer token',
          queryParams: '`months` between 1 and 6, optional `start_date` in DD-MM-YYYY',
          scenarios: ['200 success', '400 for invalid start_date format', '400 when schedule is missing', '401 without token', 'Edge: months clamped between 1 and 6'],
        }),
        tests: [
          'pm.test("Status is 200 or 400", function () {',
          '  pm.expect([200, 400]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
      request({
        name: 'Log Dosage',
        method: 'POST',
        pathTemplate: 'api/patient/dosage',
        headers: withJsonHeaders(authHeader('patient_token')),
        body: jsonBody({
          date: '15-02-2026',
        }),
        description: endpointDescription({
          summary: 'Mark one dose date as taken.',
          auth: 'Patient bearer token',
          requestBody: '`date` in DD-MM-YYYY',
          scenarios: ['200 success', '400 for invalid format', '400 when same date is logged twice', '401 without token'],
        }),
        tests: [
          'pm.test("Status is 200 or 400", function () {',
          '  pm.expect([200, 400]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
      request({
        name: 'Update Health Logs',
        method: 'POST',
        pathTemplate: 'api/patient/health-logs',
        headers: withJsonHeaders(authHeader('patient_token')),
        body: jsonBody({
          type: 'BLEEDING',
          description: 'Minor gum bleeding after brushing teeth',
        }),
        description: endpointDescription({
          summary: 'Upsert health log item by type.',
          auth: 'Patient bearer token',
          requestBody: '`type`, `description`',
          scenarios: ['200 success', '400 for invalid enum or missing description', '401 without token'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'List Notifications',
        method: 'GET',
        pathTemplate: 'api/patient/notifications',
        headers: authHeader('patient_token'),
        query: [
          { key: 'page', value: '1' },
          { key: 'limit', value: '20' },
          { key: 'is_read', value: 'false', disabled: true },
        ],
        description: endpointDescription({
          summary: 'Paginated app notifications for the patient.',
          auth: 'Patient bearer token',
          queryParams: '`page`, `limit`, `is_read`',
          scenarios: ['200 success', '400 for invalid pagination strings', '401 without token', '400 when non-patient token is used'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Mark All Notifications Read',
        method: 'PATCH',
        pathTemplate: 'api/patient/notifications/read-all',
        headers: authHeader('patient_token'),
        description: endpointDescription({
          summary: 'Marks all patient notifications as read.',
          auth: 'Patient bearer token',
          scenarios: ['200 success', '401 without token', '400 when non-patient token is used'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Mark Notification Read',
        method: 'PATCH',
        pathTemplate: 'api/patient/notifications/{{notification_id}}/read',
        headers: authHeader('patient_token'),
        description: endpointDescription({
          summary: 'Marks one patient notification as read.',
          auth: 'Patient bearer token',
          scenarios: ['200 success', '404 when notification is missing', '400 for invalid ObjectId', '401 without token'],
        }),
        tests: [
          'pm.test("Status is 200 or 404", function () {',
          '  pm.expect([200, 404]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
      request({
        name: 'Doctor Updates Summary',
        method: 'GET',
        pathTemplate: 'api/patient/doctor-updates/summary',
        headers: authHeader('patient_token'),
        description: endpointDescription({
          summary: 'Unread count and latest doctor update notification.',
          auth: 'Patient bearer token',
          scenarios: ['200 success', '401 without token', '400 when non-patient token is used'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'List Doctor Updates',
        method: 'GET',
        pathTemplate: 'api/patient/doctor-updates',
        headers: authHeader('patient_token'),
        query: [
          { key: 'unread_only', value: 'false' },
          { key: 'limit', value: '20' },
        ],
        description: endpointDescription({
          summary: 'List doctor update events derived from notification documents.',
          auth: 'Patient bearer token',
          queryParams: '`unread_only`, `limit`',
          scenarios: ['200 success', '400 for invalid query values', '401 without token'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Mark All Doctor Updates Read',
        method: 'PATCH',
        pathTemplate: 'api/patient/doctor-updates/read-all',
        headers: authHeader('patient_token'),
        description: endpointDescription({
          summary: 'Marks all unread doctor updates as read.',
          auth: 'Patient bearer token',
          scenarios: ['200 success', '401 without token'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Mark Doctor Update Read',
        method: 'PATCH',
        pathTemplate: 'api/patient/doctor-updates/{{doctor_update_event_id}}/read',
        headers: authHeader('patient_token'),
        description: endpointDescription({
          summary: 'Marks one doctor update event as read.',
          auth: 'Patient bearer token',
          scenarios: ['200 success', '404 when doctor update is missing', '400 for invalid ObjectId', '401 without token'],
        }),
        tests: [
          'pm.test("Status is 200 or 404", function () {',
          '  pm.expect([200, 404]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
      request({
        name: 'Upload Profile Picture',
        method: 'POST',
        pathTemplate: 'api/patient/profile-pic',
        headers: authHeader('patient_token'),
        body: formDataBody([
          {
            key: 'file',
            type: 'file',
            src: '/absolute/path/to/patient-profile.jpg',
            description: 'PNG, JPEG, JPG, or WEBP. Max 5 MB.',
          },
        ]),
        description: endpointDescription({
          summary: 'Upload patient profile image.',
          auth: 'Patient bearer token',
          headers: 'Multipart form-data',
          requestBody: '`file`',
          scenarios: ['200 success', '400 when file is missing', '400 when file type is invalid', '400 when file exceeds 5 MB', '401 without token'],
        }),
      }),
    ],
  },
  {
    name: 'Statistics',
    items: [
      request({
        name: 'Admin Dashboard Stats',
        method: 'GET',
        pathTemplate: 'api/statistics/admin',
        headers: authHeader('admin_token'),
        description: endpointDescription({
          summary: 'High-level admin counts for doctors, patients, and audit logs.',
          auth: 'Admin bearer token',
          scenarios: ['200 success', '401 without token', '403 for non-admin token'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Registration Trends',
        method: 'GET',
        pathTemplate: 'api/statistics/trends',
        headers: authHeader('admin_token'),
        query: [{ key: 'period', value: '7d' }],
        description: endpointDescription({
          summary: 'Registration trends across doctors and patients.',
          auth: 'Admin bearer token',
          queryParams: '`period` one of 7d, 30d, 90d, 1y',
          scenarios: ['200 success', '400 for unsupported period', '401 without token', '403 for non-admin'],
        }),
        tests: [
          'pm.test("Status is 200 or 400", function () {',
          '  pm.expect([200, 400]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
      request({
        name: 'INR Compliance Stats',
        method: 'GET',
        pathTemplate: 'api/statistics/compliance',
        headers: authHeader('admin_token'),
        description: endpointDescription({
          summary: 'INR compliance breakdown for patients.',
          auth: 'Admin bearer token',
          scenarios: ['200 success', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Doctor Workload Stats',
        method: 'GET',
        pathTemplate: 'api/statistics/workload',
        headers: authHeader('admin_token'),
        description: endpointDescription({
          summary: 'Doctor workload distribution stats.',
          auth: 'Admin bearer token',
          scenarios: ['200 success', '401 without token', '403 for non-admin'],
        }),
        tests: basicTestScript(200),
      }),
      request({
        name: 'Period Stats',
        method: 'GET',
        pathTemplate: 'api/statistics/period',
        headers: authHeader('admin_token'),
        query: [
          { key: 'start_date', value: '{{start_date}}' },
          { key: 'end_date', value: '{{end_date}}' },
        ],
        description: endpointDescription({
          summary: 'Statistics filtered by a custom date range.',
          auth: 'Admin bearer token',
          queryParams: 'Optional `start_date`, `end_date` parseable date strings',
          scenarios: ['200 success', '400 when end_date is before start_date', '400 for invalid date strings', '401 without token', '403 for non-admin'],
        }),
        tests: [
          'pm.test("Status is 200 or 400", function () {',
          '  pm.expect([200, 400]).to.include(pm.response.code);',
          '});',
        ].join('\n'),
      }),
    ],
  },
];

function makeCollection() {
  return {
    info: {
      name: collectionInfo.name,
      description: collectionInfo.description,
      schema: 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
      _postman_id: 'vitallink-backend-generated',
    },
    event: [
      {
        listen: 'prerequest',
        script: {
          type: 'text/javascript',
          exec: [
            'const requestId = pm.variables.replaceIn("{{$guid}}");',
            'pm.request.headers.upsert({ key: "x-request-id", value: requestId });',
            'pm.environment.set("request_id", requestId);',
          ],
        },
      },
    ],
    variable: [
      { key: 'base_url', value: 'http://localhost:3000' },
    ],
    item: folders.map((folder) => ({
      name: folder.name,
      description: `${folder.name} endpoints generated from source routes.`,
      item: folder.items,
    })),
  };
}

function makeEnvironment() {
  return {
    name: 'VitaLink Backend Local',
    values: envValues.map(([key, value]) => ({
      key,
      value,
      type: 'default',
      enabled: true,
    })),
    _postman_variable_scope: 'environment',
    _postman_exported_at: now,
    _postman_exported_using: 'Codex',
  };
}

function makeMatrix() {
  const lines = [
    '# VitaLink API Test Matrix',
    '',
    'Generated from backend route, validator, controller, and test analysis.',
    '',
  ];

  for (const folder of folders) {
    lines.push(`## ${folder.name}`, '');
    for (const item of folder.items) {
      const req = item.request;
      const description = typeof req.description === 'string' ? req.description : '';
      lines.push(`### ${req.method} /${req.url.path.join('/')}`, '');
      lines.push(`Request: ${item.name}`, '');
      lines.push(description, '');
    }
  }

  return lines.join('\n');
}

const collection = makeCollection();
const environment = makeEnvironment();
const matrix = makeMatrix();

fs.writeFileSync(
  path.join(outDir, 'vitallink-backend.postman_collection.json'),
  JSON.stringify(collection, null, 2) + '\n'
);

fs.writeFileSync(
  path.join(outDir, 'vitallink-backend.postman_environment.json'),
  JSON.stringify(environment, null, 2) + '\n'
);

fs.writeFileSync(
  path.join(outDir, 'api-test-matrix.md'),
  matrix + '\n'
);

module.exports = { collection, environment, matrix };
