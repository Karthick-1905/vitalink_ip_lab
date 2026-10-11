import { mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { delimiter, join } from 'node:path'
import policy from '../audit-ci.json'

const { npmAudit } = require('audit-ci')
const crossSpawn = require('cross-spawn')
const realSpawn = crossSpawn.spawn
const advisory = 'GHSA-vfj7-8cjw-p6xm'

// Exercise audit-ci's real npm report parser, path matching, thresholds and expiry
// without contacting the registry. A temporary npm executable returns a fixture.
function auditReport(
    path = ['jest', '@jest/core', 'micromatch', 'braces'],
    id = advisory,
    severity = 'high',
) {
    const vulnerabilities = Object.fromEntries(path.map((name, index) => [name, {
        name,
        severity,
        isDirect: index === 0,
        via: index < path.length - 1 ? [path[index + 1]] : [{
            source: 1234567,
            name,
            title: 'Synthetic audit-policy regression',
            url: `https://github.com/advisories/${id}`,
            severity,
            range: '*',
        }],
        effects: index === 0 ? [] : [path[index - 1]],
        nodes: [`node_modules/${name}`],
        range: '*',
        fixAvailable: false,
    }]))
    return {
        auditReportVersion: 2,
        vulnerabilities,
        metadata: { vulnerabilities: { [severity]: path.length, total: path.length } },
    }
}

describe('dependency audit policy', () => {
    let directory: string
    let originalPath: string | undefined

    beforeEach(() => {
        directory = mkdtempSync(join(tmpdir(), 'vitalink-audit-policy-'))
        originalPath = process.env.PATH
        process.env.PATH = `${directory}${delimiter}${originalPath ?? ''}`
        // Jest's environment is isolated; explicitly pass the fixture PATH to
        // the real subprocess while leaving audit-ci's report handling intact.
        jest.spyOn(crossSpawn, 'spawn').mockImplementation((command, args, options) =>
            realSpawn(command, args, { ...(options as object), env: process.env }))
        jest.spyOn(console, 'log').mockImplementation(() => {})
        jest.spyOn(console, 'warn').mockImplementation(() => {})
        jest.useFakeTimers({ doNotFake: [
            'nextTick', 'setImmediate', 'clearImmediate', 'setTimeout', 'clearTimeout',
            'setInterval', 'clearInterval', 'hrtime', 'performance', 'queueMicrotask',
        ] })
        jest.setSystemTime(new Date('2026-10-11T00:00:00Z'))
    })

    afterEach(() => {
        jest.useRealTimers()
        jest.restoreAllMocks()
        if (originalPath === undefined) delete process.env.PATH
        else process.env.PATH = originalPath
        rmSync(directory, { recursive: true, force: true })
    })

    function run(report: object) {
        const script = `process.stdout.write(${JSON.stringify(JSON.stringify(report))})`
        writeFileSync(join(directory, 'npm'), `#!/usr/bin/env node\n${script}`, { mode: 0o755 })
        writeFileSync(join(directory, 'audit.cjs'), script)
        writeFileSync(join(directory, 'npm.cmd'), `@"${process.execPath}" "${join(directory, 'audit.cjs')}" %*\r\n`)
        return npmAudit({ ...policy, directory, 'package-manager': 'npm' })
    }

    it('accepts the reviewed development advisory path before expiry', async () => {
        await expect(run(auditReport())).resolves.toMatchObject({ failedLevelsFound: [] })
    })

    it.each(['high', 'critical'])('rejects a different %s advisory on an allowed dependency path', async severity => {
        await expect(run(auditReport(undefined, 'GHSA-aaaa-bbbb-cccc', severity)))
            .rejects.toThrow('Failed security audit')
    })

    it('rejects the same advisory through an unreviewed dependency path', async () => {
        await expect(run(auditReport(['express', 'micromatch', 'braces'])))
            .rejects.toThrow('Failed security audit')
    })

    it('rejects a new direct dependency on the vulnerable package', async () => {
        await expect(run(auditReport(['braces']))).rejects.toThrow('Failed security audit')
    })

    it('rejects the reviewed advisory when the exception expires', async () => {
        jest.setSystemTime(new Date('2026-11-10T00:00:00Z'))
        await expect(run(auditReport())).rejects.toThrow('Failed security audit')
    })

    it('preserves the existing high-or-critical threshold', async () => {
        await expect(run(auditReport(['example'], 'GHSA-aaaa-bbbb-cccc', 'moderate')))
            .resolves.toMatchObject({ failedLevelsFound: [] })
    })

    it('rejects a registry error instead of treating it as a clean audit', async () => {
        await expect(run({ error: { code: 'ENOAUDIT', summary: 'Registry unavailable' } }))
            .rejects.toThrow('ENOAUDIT')
    })
})
