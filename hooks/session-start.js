// SessionStart hook: quick health check with 24-hour caching.
// Prints one-line status. Full diagnostics via /preflight.

const fs = require('fs');
const path = require('path');
const os = require('os');

const SHIPIT_DIR = fs.realpathSync(path.join(__dirname, '..'));
const CACHE_FILE = path.join(SHIPIT_DIR, '.shipit-health');
const CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours

// Check cache
try {
  if (fs.existsSync(CACHE_FILE)) {
    const cache = JSON.parse(fs.readFileSync(CACHE_FILE, 'utf8'));
    const age = Date.now() - new Date(cache.timestamp).getTime();
    if (age < CACHE_TTL_MS && cache.status === 'healthy') {
      console.log(`ShipIt v3: healthy (cached ${Math.round(age / 3600000)}h ago)`);
      process.exit(0);
    }
  }
} catch {
  // Cache read failed — run fresh check
}

// Quick health check
const issues = [];

// 1. Symlink
const link = path.join(os.homedir(), '.claude', 'local-plugins', 'shipit');
try {
  const stat = fs.lstatSync(link);
  if (!stat.isSymbolicLink()) issues.push('symlink not a link');
} catch {
  issues.push('symlink missing');
}

// 2. Plugin manifest
const manifest = path.join(SHIPIT_DIR, '.claude-plugin', 'plugin.json');
try {
  JSON.parse(fs.readFileSync(manifest, 'utf8'));
} catch {
  issues.push('plugin.json invalid');
}

// 3. Agent count
const agentsDir = path.join(SHIPIT_DIR, 'agents');
try {
  const agents = fs.readdirSync(agentsDir).filter(f => f.endsWith('.md'));
  if (agents.length < 13) issues.push(`only ${agents.length}/13 agents`);
} catch {
  issues.push('agents dir missing');
}

// 4. Commands count
const cmdsDir = path.join(SHIPIT_DIR, 'commands');
try {
  const cmds = fs.readdirSync(cmdsDir).filter(f => f.endsWith('.md'));
  if (cmds.length < 10) issues.push(`only ${cmds.length}/10 commands`);
} catch {
  issues.push('commands dir missing');
}

// Write cache and report
const status = issues.length === 0 ? 'healthy' : 'degraded';
const cache = {
  timestamp: new Date().toISOString(),
  status,
  issues,
};

try {
  fs.writeFileSync(CACHE_FILE, JSON.stringify(cache, null, 2));
} catch {
  // Cache write failed — non-fatal
}

if (issues.length === 0) {
  console.log('ShipIt v3: healthy');
} else {
  console.log(`ShipIt v3: ${issues.join(', ')}. Run /preflight for details.`);
}
