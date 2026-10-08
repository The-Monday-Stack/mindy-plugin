#!/usr/bin/env bun
import { openSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { spawn } from "node:child_process";

const WORKER_ENVIRONMENT_NAMES = [
	"HOME", "PATH", "TMPDIR", "TEMP", "TMP", "USER", "LOGNAME", "SHELL", "LANG", "LC_ALL", "LC_CTYPE", "TZ",
	"MTS_PRODUCT", "MTS_CONTENT_ROOT", "MTS_STATE_ROOT", "MTS_RUNTIME_SCRATCH_DIR",
	"CODEX_CLI_PATH", "CODEX_HOME", "CODEX_THREAD_ID", "CODEX_SESSION_ID", "CODEX_INTERNAL_ORIGINATOR_OVERRIDE", "CODEX_SANDBOX",
] as const;

export function buildMtsWorkerEnvironment(source: NodeJS.ProcessEnv = process.env): Record<string, string> {
	const env: Record<string, string> = {};
	for (const name of WORKER_ENVIRONMENT_NAMES) {
		const value = source[name]; if (value !== undefined) env[name] = value;
	}
	return env;
}

function start(name: string, entrypoint: string, logRoot: string, env: Record<string, string>): void {
	const output = openSync(join(logRoot, `${name}.log`), "a", 0o600);
	const error = openSync(join(logRoot, `${name}-error.log`), "a", 0o600);
	const child = spawn(process.execPath, [entrypoint, ...(name === "save-failures" ? ["--resend"] : [])], { detached: true, stdio: ["ignore", output, error], env });
	child.unref();
}

if (import.meta.main) {
	const contentRoot = process.env.MTS_CONTENT_ROOT;
	const stateRoot = process.env.MTS_STATE_ROOT;
	if (!contentRoot || !stateRoot || process.env.MTS_PRODUCT !== "mts") throw new Error("MINDY TimeSaver cannot find its installed folders.");
	const installedParts = join(contentRoot, "timesaver-install");
	const { migrateMemberTimeSaver } = await import(join(contentRoot, "MY-MIND/MY-SYSTEM/utilities/mts-member-update.ts"));
	migrateMemberTimeSaver(contentRoot, process.env.MTS_RUNTIME_SCRATCH_DIR ?? join(stateRoot, "runtime-scratch"));
	const { timeSaverStatus, areTimeconeReportsOff } = await import(join(installedParts, "runtime/privacy.ts"));
 // No per-session off history is kept. A later /mindyend checks the current setting.
 const current = timeSaverStatus();
 if (current.status !== 0) {
  process.stdout.write(`${current.message} Tell the person this in one line.\n`);
  process.exit(0);
 }
	const logRoot = join(stateRoot, "logs");
	mkdirSync(logRoot, { recursive: true, mode: 0o700 });
	const env = buildMtsWorkerEnvironment();
	if (!areTimeconeReportsOff()) start("save-failures", join(contentRoot, "bin/save-failure.ts"), logRoot, env);
	start("capture", join(installedParts, "runtime/timesaver-capture-worker.ts"), logRoot, env);
	start("compression", join(contentRoot, "MY-MIND/MY-SYSTEM/hooks/CompressIfDue.worker.ts"), logRoot, env);
}
