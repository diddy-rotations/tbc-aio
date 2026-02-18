/**
 * Dev Watcher — Watches for .lua changes and rebuilds on change
 *
 * Thin file watcher that delegates all build logic to build.js.
 * Detects .lua file changes, determines affected classes, and triggers
 * a sync to TellMeWhen SavedVariables.
 *
 * Also watches the SavedVariables file itself. When the game overwrites
 * it (e.g. on /reload), re-syncs our code into it immediately.
 *
 * Usage: node dev-watch.js
 *
 * Requires dev.ini in project root (see dev.ini.example).
 */

const fs = require('fs');

const build = require('./build');

const { INI_PATH } = build;

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

if (!fs.existsSync(INI_PATH)) {
    console.error('Error: dev.ini not found in project root.');
    console.error('');
    console.error('Create dev.ini from the example:');
    console.error('  cp dev.ini.example dev.ini');
    console.error('');
    console.error('Then edit it with your SavedVariables path.');
    process.exit(1);
}

const config = build.parseINI(fs.readFileSync(INI_PATH, 'utf8'));

if (!config.paths || !config.paths.savedvariables) {
    console.error('Error: dev.ini missing [paths] savedvariables');
    process.exit(1);
}

const aioDir = build.getAIODir(config);
const svPath = config.paths.savedvariables;

// ---------------------------------------------------------------------------
// Write Tracking — distinguish our writes from game writes
// ---------------------------------------------------------------------------

let lastOurWriteTime = 0;
const OUR_WRITE_COOLDOWN_MS = 2000;

/** Wrapper that marks a sync as "ours" so the SV watcher ignores it. */
function syncAndMark(classNames) {
    build.syncToSavedVariables(config, classNames);
    lastOurWriteTime = Date.now();
}

// ---------------------------------------------------------------------------
// Initial State
// ---------------------------------------------------------------------------

let classes = build.discoverClasses(aioDir);
if (classes.length === 0) {
    console.error(`Error: No class directories found in ${aioDir}`);
    process.exit(1);
}

const classSummary = classes.map(c => {
    const mods = build.discoverModules(c, aioDir);
    return `${c}: ${mods.length} modules`;
}).join(', ');

console.log(`[${build.timestamp()}] Watching ${aioDir} — ${classes.length} class(es) (${classSummary})`);

// Initial full sync
syncAndMark(classes);

// ---------------------------------------------------------------------------
// Source File Watcher
// ---------------------------------------------------------------------------

let debounceTimer = null;
let pendingChanges = new Set();

function handleChange(_eventType, filename) {
    if (!filename || !filename.endsWith('.lua')) return;

    pendingChanges.add(filename);

    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
        const changes = [...pendingChanges];
        pendingChanges.clear();
        debounceTimer = null;

        // Determine which classes need rebuild
        const affectedClasses = new Set();
        let isShared = false;

        for (const file of changes) {
            const normalized = file.replace(/\\/g, '/');
            const parts = normalized.split('/');

            if (parts.length === 1) {
                isShared = true;
                console.log(`[${build.timestamp()}] Changed: ${file} (shared)`);
            } else {
                affectedClasses.add(parts[0]);
                console.log(`[${build.timestamp()}] Changed: ${parts.join('/')}`);
            }
        }

        // Check for new class directories
        const currentClasses = build.discoverClasses(aioDir);
        for (const c of currentClasses) {
            if (!classes.includes(c)) {
                classes.push(c);
                affectedClasses.add(c);
                console.log(`[${build.timestamp()}] [NEW CLASS] Detected ${c}/ — creating profile`);
            }
        }

        // If shared file changed, rebuild all classes
        const toSync = isShared ? [...classes] : [...affectedClasses];
        if (toSync.length > 0) {
            syncAndMark(toSync);
        }
    }, 300);
}

fs.watch(aioDir, { recursive: true }, handleChange);

// ---------------------------------------------------------------------------
// SavedVariables Watcher — re-sync after game overwrites (e.g. /reload)
// ---------------------------------------------------------------------------

let svDebounceTimer = null;

function handleSVChange() {
    // Ignore changes we just caused
    if (Date.now() - lastOurWriteTime < OUR_WRITE_COOLDOWN_MS) return;

    if (svDebounceTimer) clearTimeout(svDebounceTimer);
    svDebounceTimer = setTimeout(() => {
        svDebounceTimer = null;

        // Double-check the cooldown (might have been set during debounce wait)
        if (Date.now() - lastOurWriteTime < OUR_WRITE_COOLDOWN_MS) return;

        if (!fs.existsSync(svPath)) return;

        console.log(`[${build.timestamp()}] [RELOAD] SavedVariables overwritten externally — re-syncing all classes`);
        syncAndMark(classes);
    }, 500);
}

// fs.watchFile uses polling — more reliable than fs.watch for files modified
// by external programs (especially games that do atomic write-replace).
fs.watchFile(svPath, { interval: 1000 }, (curr, prev) => {
    if (curr.mtimeMs !== prev.mtimeMs) {
        handleSVChange();
    }
});

console.log(`[${build.timestamp()}] Watching for changes... (Ctrl+C to stop)`);
console.log(`[${build.timestamp()}] Watching SavedVariables for external changes (e.g. /reload)`);
